import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Captures the widget tree under a `RepaintBoundary` as PNG bytes.
///
/// Pixel-exact and free of system UI, unlike a screen recording frame.
class StillCapture {
  /// Creates a capture bound to the `RepaintBoundary` keyed [boundaryKey].
  const StillCapture(
    this.boundaryKey, {
    this.resumeTimeout = const Duration(seconds: 5),
  });

  /// Key of the `RepaintBoundary` wrapping the app.
  final GlobalKey boundaryKey;

  /// Maximum time [capture] waits for the app to resume.
  final Duration resumeTimeout;

  /// Waits until the app is resumed before rendering a frame.
  ///
  /// A null lifecycle state is treated as foreground for early startup and
  /// tests that have not received a lifecycle event yet.
  Future<void> ensureForeground() async {
    final binding = WidgetsBinding.instance;
    final state = binding.lifecycleState;
    if (state == null || state == AppLifecycleState.resumed) return;

    final resumed = Completer<void>();
    final listener = AppLifecycleListener(onResume: resumed.complete);
    try {
      if (binding.lifecycleState == AppLifecycleState.resumed) return;
      await resumed.future.timeout(resumeTimeout);
    } on TimeoutException {
      throw StateError(
        'still capture: app is in the background (lifecycle: ${state.name})',
      );
    } finally {
      listener.dispose();
    }
  }

  /// Renders the boundary at [pixelRatio] and encodes it as PNG.
  ///
  /// Throws [StateError] if the boundary is not mounted or the app stays in
  /// the background.
  Future<Uint8List> capture(double pixelRatio) async {
    await ensureForeground();
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
