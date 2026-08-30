import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Captures the widget tree under a `RepaintBoundary` as PNG bytes.
///
/// Pixel-exact and free of system UI, unlike a screen recording frame.
class StillCapture {
  /// Creates a capture bound to the `RepaintBoundary` keyed [boundaryKey].
  const StillCapture(this.boundaryKey);

  /// Key of the `RepaintBoundary` wrapping the app.
  final GlobalKey boundaryKey;

  /// Renders the boundary at [pixelRatio] and encodes it as PNG.
  ///
  /// Throws [StateError] if the boundary is not mounted.
  Future<Uint8List> capture(double pixelRatio) async {
    final render = boundaryKey.currentContext?.findRenderObject();
    if (render is! RenderRepaintBoundary) {
      throw StateError('still capture: RepaintBoundary not mounted');
    }
    final image = await render.toImage(pixelRatio: pixelRatio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('still capture: PNG encoding failed');
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }
}
