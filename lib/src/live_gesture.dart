import 'package:flutter/widgets.dart';

export 'gesture_driver.dart';

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
    final durationMs = _gestureDurationMs(json, kind);
    final at = _gesturePoint(json, kind, GestureKind.tap, _GestureJsonKeys.at);
    final from = _gesturePoint(
      json,
      kind,
      GestureKind.drag,
      _GestureJsonKeys.from,
    );
    final to = _gesturePoint(json, kind, GestureKind.drag, _GestureJsonKeys.to);
    final center = _gesturePoint(
      json,
      kind,
      GestureKind.pinch,
      _GestureJsonKeys.center,
    );
    final scale = _gestureScale(json, kind);
    final target = _gestureTarget(json);

    return LiveGesture(
      kind: kind,
      duration: Duration(milliseconds: durationMs),
      at: at,
      from: from,
      to: to,
      center: center,
      scale: scale,
      screen: target.screen,
      section: target.section,
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
    if (!_hasPointShape(raw)) {
      throw FormatException('$name must be a two-number point');
    }
    final coordinates = raw as List;
    final x = coordinates[0];
    final y = coordinates[1];
    if (x is! num || y is! num) {
      throw FormatException('$name must be a two-number point');
    }
    final point = Offset(x.toDouble(), y.toDouble());
    if (!_isUnitCoordinate(point.dx) || !_isUnitCoordinate(point.dy)) {
      throw FormatException('$name coordinates must be between 0 and 1');
    }
    return point;
  }

  static bool _hasPointShape(Object? raw) =>
      raw is List && raw.length == _GestureJsonValues.pointLength;

  static bool _isUnitCoordinate(double value) =>
      value.isFinite && value >= 0 && value <= 1;
}

int _gestureDurationMs(Map<String, dynamic> json, GestureKind kind) {
  final durationMs = json[_GestureJsonKeys.durationMs];
  if (durationMs != null && (durationMs is! int || durationMs <= 0)) {
    throw FormatException('duration_ms must be a positive integer');
  }
  if (durationMs is int) return durationMs;
  return kind == GestureKind.tap
      ? _GestureJsonValues.defaultTapDurationMs
      : _GestureJsonValues.defaultDurationMs;
}

Offset? _gesturePoint(
  Map<String, dynamic> json,
  GestureKind kind,
  GestureKind expectedKind,
  String field,
) => kind == expectedKind ? LiveGesture._point(json[field], field) : null;

double? _gestureScale(Map<String, dynamic> json, GestureKind kind) {
  if (kind != GestureKind.pinch) return null;
  final rawScale = json[_GestureJsonKeys.scale];
  if (rawScale is! num) {
    throw FormatException('pinch scale must be a positive number');
  }
  final scale = rawScale.toDouble();
  if (!scale.isFinite || scale <= 0) {
    throw FormatException('pinch scale must be a positive number');
  }
  return scale;
}

({String? screen, String? section}) _gestureTarget(Map<String, dynamic> json) {
  final screen = json[_GestureJsonKeys.screen];
  final section = json[_GestureJsonKeys.section];
  if (screen != null && screen is! String) {
    throw FormatException('screen must be a string');
  }
  if (section != null && section is! String) {
    throw FormatException('section must be a string');
  }
  if (section != null && screen == null) {
    throw FormatException('section requires screen');
  }
  return (screen: screen as String?, section: section as String?);
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
