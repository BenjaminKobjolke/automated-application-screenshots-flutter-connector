import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// A touch gesture supported by the live screenshot protocol.
enum GestureKind {
  /// A brief press at one point.
  tap,

  /// A one-finger move from one point to another.
  drag,

  /// A two-finger scale around a centre point.
  pinch;

  /// The protocol spelling for this gesture kind.
  String get wireName => switch (this) {
    tap => _GestureJsonValues.tap,
    drag => _GestureJsonValues.drag,
    pinch => _GestureJsonValues.pinch,
  };

  /// Parses the protocol spelling for a gesture kind.
  static GestureKind parse(Object? value) => switch (value) {
    _GestureJsonValues.tap => tap,
    _GestureJsonValues.drag => drag,
    _GestureJsonValues.pinch => pinch,
    _ => throw FormatException('unknown or missing gesture kind: $value'),
  };
}

/// A validated gesture request with points expressed as box fractions.
final class LiveGesture {
  /// Creates a validated gesture request.
  const LiveGesture({
    required this.kind,
    required this.duration,
    this.at,
    this.from,
    this.to,
    this.center,
    this.scale,
    this.screen,
    this.section,
  });

  /// Parses and validates a `gesture` command object.
  factory LiveGesture.fromJson(Map<String, dynamic> json) {
    final kind = GestureKind.parse(json[_GestureJsonKeys.kind]);
    final durationMs = json[_GestureJsonKeys.durationMs];
    final defaultDuration = kind == GestureKind.tap
        ? _GestureJsonValues.defaultTapDurationMs
        : _GestureJsonValues.defaultDurationMs;
    if (durationMs != null && (durationMs is! int || durationMs <= 0)) {
      throw FormatException('duration_ms must be a positive integer');
    }

    final at = kind == GestureKind.tap
        ? _point(json[_GestureJsonKeys.at], _GestureJsonKeys.at)
        : null;
    final from = kind == GestureKind.drag
        ? _point(json[_GestureJsonKeys.from], _GestureJsonKeys.from)
        : null;
    final to = kind == GestureKind.drag
        ? _point(json[_GestureJsonKeys.to], _GestureJsonKeys.to)
        : null;
    final center = kind == GestureKind.pinch
        ? _point(json[_GestureJsonKeys.center], _GestureJsonKeys.center)
        : null;
    final rawScale = json[_GestureJsonKeys.scale];
    double? scale;
    if (kind == GestureKind.pinch) {
      if (rawScale is! num) {
        throw FormatException('pinch scale must be a positive number');
      }
      scale = rawScale.toDouble();
      if (!scale.isFinite || scale <= 0) {
        throw FormatException('pinch scale must be a positive number');
      }
    }

    final rawScreen = json[_GestureJsonKeys.screen];
    final rawSection = json[_GestureJsonKeys.section];
    if (rawScreen != null && rawScreen is! String) {
      throw FormatException('screen must be a string');
    }
    if (rawSection != null && rawSection is! String) {
      throw FormatException('section must be a string');
    }
    if (rawSection != null && rawScreen == null) {
      throw FormatException('section requires screen');
    }

    return LiveGesture(
      kind: kind,
      duration: Duration(milliseconds: durationMs as int? ?? defaultDuration),
      at: at,
      from: from,
      to: to,
      center: center,
      scale: scale,
      screen: rawScreen as String?,
      section: rawSection as String?,
    );
  }

  /// Gesture being performed.
  final GestureKind kind;

  /// Time spent pressing or moving, excluding the final settling hold.
  final Duration duration;

  /// Tap position as a fraction of the target box.
  final Offset? at;

  /// Drag start position as a fraction of the target box.
  final Offset? from;

  /// Drag end position as a fraction of the target box.
  final Offset? to;

  /// Pinch centre as a fraction of the target box.
  final Offset? center;

  /// Pinch scale factor; values above one zoom in.
  final double? scale;

  /// Screen that owns [section], when targeting a registered section.
  final String? screen;

  /// Registered screen section to use as the target box.
  final String? section;

  static Offset _point(Object? raw, String name) {
    if (raw is! List || raw.length != _GestureJsonValues.pointLength) {
      throw FormatException('$name must be a two-number point');
    }
    final x = raw[0];
    final y = raw[1];
    if (x is! num || y is! num) {
      throw FormatException('$name must be a two-number point');
    }
    final point = Offset(x.toDouble(), y.toDouble());
    if (!point.dx.isFinite ||
        !point.dy.isFinite ||
        point.dx < 0 ||
        point.dx > 1 ||
        point.dy < 0 ||
        point.dy > 1) {
      throw FormatException('$name coordinates must be between 0 and 1');
    }
    return point;
  }
}

/// Sends touch pointer events through Flutter's normal gesture recognizers.
final class GestureDriver {
  static const Duration _moveInterval = Duration(milliseconds: 16);
  static const Duration _settleHold = Duration(milliseconds: 60);
  static const double _pinchRadiusFraction = 0.2;
  static final Stopwatch _eventClock = Stopwatch()..start();
  static int _nextPointer = 1;

  /// Performs [gesture] relative to the global-coordinate [box].
  Future<void> perform(LiveGesture gesture, Rect box) async {
    if (box.isEmpty || !box.width.isFinite || !box.height.isFinite) {
      throw StateError('gesture target has no finite size');
    }
    switch (gesture.kind) {
      case GestureKind.tap:
        await _tap(_position(box, gesture.at!), gesture.duration);
      case GestureKind.drag:
        await _drag(
          _position(box, gesture.from!),
          _position(box, gesture.to!),
          gesture.duration,
        );
      case GestureKind.pinch:
        await _pinch(
          box,
          _position(box, gesture.center!),
          gesture.scale!,
          gesture.duration,
        );
    }
  }

  Future<void> _tap(Offset point, Duration duration) async {
    final pointer = _allocatePointer();
    _send(PointerDownEvent(pointer: pointer, position: point));
    await Future<void>.delayed(duration);
    _send(PointerUpEvent(pointer: pointer, position: point));
  }

  Future<void> _drag(Offset start, Offset end, Duration duration) async {
    final pointer = _allocatePointer();
    _send(PointerDownEvent(pointer: pointer, position: start));
    await _movePointers(
      duration,
      (progress) => _send(
        PointerMoveEvent(
          pointer: pointer,
          position: Offset.lerp(start, end, progress)!,
        ),
      ),
    );
    await Future<void>.delayed(_settleHold);
    _send(PointerUpEvent(pointer: pointer, position: end));
  }

  Future<void> _pinch(
    Rect box,
    Offset center,
    double scale,
    Duration duration,
  ) async {
    final radius = box.shortestSide * _pinchRadiusFraction;
    final startLeft = center - Offset(radius, 0);
    final startRight = center + Offset(radius, 0);
    final endLeft = center - Offset(radius * scale, 0);
    final endRight = center + Offset(radius * scale, 0);
    final leftPointer = _allocatePointer();
    final rightPointer = _allocatePointer();
    _send(PointerDownEvent(pointer: leftPointer, position: startLeft));
    _send(PointerDownEvent(pointer: rightPointer, position: startRight));
    await _movePointers(duration, (progress) {
      _send(
        PointerMoveEvent(
          pointer: leftPointer,
          position: Offset.lerp(startLeft, endLeft, progress)!,
        ),
      );
      _send(
        PointerMoveEvent(
          pointer: rightPointer,
          position: Offset.lerp(startRight, endRight, progress)!,
        ),
      );
    });
    await Future<void>.delayed(_settleHold);
    _send(PointerUpEvent(pointer: leftPointer, position: endLeft));
    _send(PointerUpEvent(pointer: rightPointer, position: endRight));
  }

  Future<void> _movePointers(
    Duration duration,
    void Function(double progress) move,
  ) async {
    final durationMs = duration.inMilliseconds;
    final steps = (durationMs / _moveInterval.inMilliseconds).ceil();
    var previousMs = 0;
    for (var step = 1; step <= steps; step++) {
      final currentMs = (durationMs * step / steps).round();
      await Future<void>.delayed(
        Duration(milliseconds: currentMs - previousMs),
      );
      move(step / steps);
      previousMs = currentMs;
    }
  }

  static Offset _position(Rect box, Offset fraction) =>
      box.topLeft + Offset(fraction.dx * box.width, fraction.dy * box.height);

  static int _allocatePointer() => _nextPointer++;

  static void _send(PointerEvent event) {
    GestureBinding.instance.handlePointerEvent(
      event.copyWith(
        kind: PointerDeviceKind.touch,
        timeStamp: _eventClock.elapsed,
      ),
    );
  }
}

abstract final class _GestureJsonKeys {
  static const kind = 'kind';
  static const durationMs = 'duration_ms';
  static const at = 'at';
  static const from = 'from';
  static const to = 'to';
  static const center = 'center';
  static const scale = 'scale';
  static const screen = 'screen';
  static const section = 'section';
}

abstract final class _GestureJsonValues {
  static const tap = 'tap';
  static const drag = 'drag';
  static const pinch = 'pinch';
  static const pointLength = 2;
  static const defaultDurationMs = 300;
  static const defaultTapDurationMs = 100;
}
