import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'frame_settle.dart';
import 'full_length_capture.dart';
import 'live_screens.dart';
import 'protocol.dart';

/// Prepares app state for a live screen, using the same inputs as a demo.
typedef PrepareCallback = Future<void> Function(
  Map<String, String> settings,
  String? language,
);

/// Applies an in-memory app theme before a live screen is opened.
typedef ThemeCallback = Future<void> Function(Brightness brightness);

/// Executes live screen commands and returns one protocol event per command.
class LiveSession {
  /// Creates a session with the app's registered screens and capture boundary.
  const LiveSession({
    required LiveScreenRegistry screens,
    required LiveCapture capture,
    PrepareCallback? onPrepare,
    ThemeCallback? onSetTheme,
  }) : _screens = screens,
       _capture = capture,
       _onPrepare = onPrepare,
       _onSetTheme = onSetTheme;

  final LiveScreenRegistry _screens;
  final LiveCapture _capture;
  final PrepareCallback? _onPrepare;
  final ThemeCallback? _onSetTheme;

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
        SetThemeCommand() => await _setTheme(command),
        NavigateCommand() => await _navigate(command),
        ScreenshotCommand() => await _screenshot(command),
        ResetCommand() => await _reset(command),
      };
    } on Object catch (error) {
      return DemoEvents.error(error.toString());
    }
  }

  Future<Map<String, Object>> _navigate(NavigateCommand command) async {
    final themeHook = command.theme == null ? null : _themeHook;
    final screen = _screens.get(command.screen);
    final sectionKey = command.section == null
        ? null
        : screen.section(command.section!);
    final open = screen.opener(command.recordId);
    await _onPrepare?.call(command.settings, command.language);
    if (command.theme case final theme?) await themeHook!(theme);
    await open();
    await waitForSettledFrame();
    if (sectionKey != null) {
      final context = sectionKey.currentContext;
      if (context == null) {
        throw StateError(
          'section "${command.section}" of screen "${command.screen}" is not built',
        );
      }
      await Scrollable.ensureVisible(context, alignment: 0);
      await waitForSettledFrame();
    }
    return DemoEvents.navigated(command.screen);
  }

  ThemeCallback get _themeHook =>
      _onSetTheme ??
      (throw StateError(
        'theme switching is not supported: the app registered no onSetTheme hook',
      ));

  Future<Map<String, Object>> _setTheme(SetThemeCommand command) async {
    await _themeHook(command.theme);
    await waitForSettledFrame();
    return DemoEvents.themeSet(command.theme);
  }

  Future<Map<String, Object>> _screenshot(ScreenshotCommand command) async {
    await waitForSettledFrame();
    final png = await _capture.capture(command.pixelRatio, full: command.full);
    return DemoEvents.screenshot(command.name, png);
  }

  Future<Map<String, Object>> _reset(ResetCommand command) async {
    await _onPrepare?.call(command.settings, command.language);
    await waitForSettledFrame();
    return DemoEvents.resetDone();
  }
}
