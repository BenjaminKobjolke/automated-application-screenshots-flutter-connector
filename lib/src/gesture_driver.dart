import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'live_gesture.dart';

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
