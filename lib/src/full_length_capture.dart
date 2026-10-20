import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'frame_settle.dart';
import 'still_capture.dart';

/// Captures the current app boundary, optionally expanding its main scrollable.
class LiveCapture {
  /// Creates a capture using the host's [extraHeight] layout notifier.
  const LiveCapture(this._still, this._extraHeight);

  static const double _maxPhysicalPixels = 16384;
  static const int _maxExpansionRounds = 3;

  final StillCapture _still;
  final ValueNotifier<double?> _extraHeight;

  /// Captures the viewport or the full rendered extent of the active screen.
  Future<Uint8List> capture(double pixelRatio, {bool full = false}) async {
    if (!full) return _still.capture(pixelRatio);

    await waitForSettledFrame();
    final scrollable = _findScrollable();
    if (scrollable == null || !scrollable.position.hasContentDimensions) {
      return _still.capture(pixelRatio);
    }

    var extraHeight = 0.0;
    try {
      scrollable.position.jumpTo(0);
      await waitForSettledFrame();
      final maxLogicalHeight = _maxPhysicalPixels / pixelRatio;
      final maxExtraHeight = (maxLogicalHeight - _boundary.size.height)
          .clamp(0.0, double.infinity)
          .toDouble();

      for (var round = 0; round < _maxExpansionRounds; round++) {
        final remaining = scrollable.position.maxScrollExtent;
        if (remaining <= 0 || extraHeight >= maxExtraHeight) break;
        extraHeight = (extraHeight + remaining)
            .clamp(0.0, maxExtraHeight)
            .toDouble();
        _extraHeight.value = extraHeight;
        await waitForSettledFrame();
      }
      return await _still.capture(pixelRatio);
    } finally {
      _extraHeight.value = null;
      await waitForSettledFrame();
    }
  }

  RenderRepaintBoundary get _boundary {
    final render = _still.boundaryKey.currentContext?.findRenderObject();
    if (render is! RenderRepaintBoundary) {
      throw StateError('still capture: RepaintBoundary not mounted');
    }
    return render;
  }

  ScrollableState? _findScrollable() {
    final context = _still.boundaryKey.currentContext;
    if (context == null) return null;
    final scrollables = <ScrollableState>[];
    void visit(Element element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        final state = element.state as ScrollableState;
        final position = state.position;
        final isVertical =
            position.axisDirection == AxisDirection.down ||
            position.axisDirection == AxisDirection.up;
        if (isVertical &&
            position.hasContentDimensions &&
            ModalRoute.of(element)?.isCurrent != false) {
          scrollables.add(state);
        }
      }
      element.visitChildElements(visit);
    }

    context.visitChildElements(visit);
    if (scrollables.isEmpty) return null;
    scrollables.sort(
      (left, right) => right.position.maxScrollExtent.compareTo(
        left.position.maxScrollExtent,
      ),
    );
    return scrollables.first;
  }
}
