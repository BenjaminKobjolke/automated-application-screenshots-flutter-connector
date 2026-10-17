import 'package:flutter/foundation.dart';

import 'frame_settle.dart';
import 'live_screens.dart';
import 'protocol.dart';
import 'still_capture.dart';

/// Prepares app state for a live screen, using the same inputs as a demo.
typedef PrepareCallback = Future<void> Function(
  Map<String, String> settings,
  String? language,
);

/// Executes live screen commands and returns one protocol event per command.
class LiveSession {
  /// Creates a session with the app's registered screens and capture boundary.
  const LiveSession({
    required LiveScreenRegistry screens,
    required StillCapture still,
    PrepareCallback? onPrepare,
  }) : _screens = screens,
       _still = still,
       _onPrepare = onPrepare;

  final LiveScreenRegistry _screens;
  final StillCapture _still;
  final PrepareCallback? _onPrepare;

  /// Handles [command], converting failures to the protocol's error event.
  Future<Map<String, Object>> handle(LiveCommand command) async {
    if (kReleaseMode) {
      return DemoEvents.error(
        'live commands are only available in debug builds',
      );
    }

    try {
      return switch (command) {
        ListScreensCommand() => DemoEvents.screens([
          for (final screen in _screens.all) screen.toJson(),
        ]),
        NavigateCommand() => await _navigate(command),
        ScreenshotCommand() => await _screenshot(command),
        ResetCommand() => await _reset(command),
      };
    } on Object catch (error) {
      return DemoEvents.error(error.toString());
    }
  }

  Future<Map<String, Object>> _navigate(NavigateCommand command) async {
    await _onPrepare?.call(command.settings, command.language);
    await _screens.get(command.screen).open();
    await waitForSettledFrame();
    return DemoEvents.navigated(command.screen);
  }

  Future<Map<String, Object>> _screenshot(ScreenshotCommand command) async {
    await waitForSettledFrame();
    final png = await _still.capture(command.pixelRatio);
    return DemoEvents.screenshot(command.name, png);
  }

  Future<Map<String, Object>> _reset(ResetCommand command) async {
    await _onPrepare?.call(command.settings, command.language);
    await waitForSettledFrame();
    return DemoEvents.resetDone();
  }
}
