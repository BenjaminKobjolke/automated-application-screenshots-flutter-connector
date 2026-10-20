import 'package:flutter/foundation.dart';

import 'steps.dart';

export 'protocol_events.dart';

/// Names used by the JSON-lines command and event protocol.
abstract final class ProtocolNames {
  /// The command that starts a demo.
  static const String start = 'start';

  /// The command that lists registered screens.
  static const String listScreens = 'list_screens';

  /// The command that opens a registered screen.
  static const String navigate = 'navigate';

  /// The command that changes the app's theme.
  static const String setTheme = 'set_theme';

  /// The command that captures the current screen.
  static const String screenshot = 'screenshot';

  /// The command that restores the app's initial state.
  static const String reset = 'reset';

  /// The event reporting registered screens.
  static const String screens = 'screens';

  /// The event confirming a screen navigation.
  static const String navigated = 'navigated';

  /// The event confirming the app's theme was changed.
  static const String themeSet = 'theme_set';

  /// The event confirming a reset.
  static const String resetDone = 'reset_done';

  /// The event announcing that demo playback started.
  static const String demoStarted = 'demo_started';

  /// The event announcing that demo playback finished.
  static const String demoEnded = 'demo_ended';

  /// The event announcing an mp4 payload.
  static const String video = 'video';

  /// The event reporting a command failure.
  static const String error = 'error';
}

/// A command received from the screenshot tool.
sealed class ToolCommand {
  /// Creates a tool command.
  const ToolCommand();

  /// Parses one command object from the tool's JSON-lines protocol.
  factory ToolCommand.fromJson(Map<String, dynamic> json) {
    return switch (json['command']) {
      ProtocolNames.start => StartCommand.fromJson(json),
      ProtocolNames.listScreens => const ListScreensCommand(),
      ProtocolNames.navigate => NavigateCommand.fromJson(json),
      ProtocolNames.setTheme => SetThemeCommand.fromJson(json),
      ProtocolNames.screenshot => ScreenshotCommand.fromJson(json),
      ProtocolNames.reset => ResetCommand.fromJson(json),
      _ => throw FormatException('unknown tool command: ${json['command']}'),
    };
  }
}

/// A live-session command that operates on named screens.
sealed class LiveCommand extends ToolCommand {
  /// Creates a live-session command.
  const LiveCommand();
}

/// The tool's `set_theme` command: applies a theme before navigation.
final class SetThemeCommand extends LiveCommand {
  /// Creates a theme command for [theme].
  const SetThemeCommand({required this.theme});

  /// Parses the JSON object the tool sent.
  ///
  /// Throws [FormatException] if the theme is missing or unsupported.
  factory SetThemeCommand.fromJson(Map<String, dynamic> json) {
    final theme = _parseTheme(json['theme']);
    if (theme == null) {
      throw FormatException('set_theme command requires a theme');
    }
    return SetThemeCommand(theme: theme);
  }

  /// Theme requested by the tool.
  final Brightness theme;
}

/// The tool's `start` command: which demo to play and how.
final class StartCommand extends ToolCommand {
  /// Creates a start command.
  const StartCommand({
    required this.demo,
    required this.video,
    this.pixelRatio = 1.0,
    this.settings = const {},
    this.language,
    this.texts = const {},
    this.steps,
  });

  /// Parses the JSON object the tool sent.
  ///
  /// Throws [FormatException] if it is not a `start` command.
  factory StartCommand.fromJson(Map<String, dynamic> json) {
    if (json['command'] != ProtocolNames.start || json['demo'] is! int) {
      throw FormatException('not a start command: $json');
    }
    final rawSteps = json['steps'];
    return StartCommand(
      demo: json['demo'] as int,
      video: json['video'] == true,
      pixelRatio: (json['pixel_ratio'] as num? ?? 1).toDouble(),
      settings: _stringMap(json['settings']),
      language: json['language'] as String?,
      texts: _stringMap(json['texts']),
      steps: rawSteps is List && rawSteps.isNotEmpty
          ? [
              for (final s in rawSteps)
                DemoStep.fromJson(Map<String, dynamic>.from(s as Map)),
            ]
          : null,
    );
  }

  /// Demo id from the tool's config.
  final int demo;

  /// Whether to screen-record (false = stills only, no consent dialog).
  final bool video;

  /// Device pixel ratio for stills.
  final double pixelRatio;

  /// The config's `app_settings`, meaning is the app's own.
  final Map<String, String> settings;

  /// UI language for this run, or null.
  final String? language;

  /// Placeholder -> localized text for `type_text` steps.
  final Map<String, String> texts;

  /// Steps sent by the tool; null = play the demo registered under [demo].
  final List<DemoStep>? steps;
}

/// Requests the list of screens registered by the app.
final class ListScreensCommand extends LiveCommand {
  /// Creates a list-screens command.
  const ListScreensCommand();
}

/// Opens a registered screen after applying optional app settings.
final class NavigateCommand extends LiveCommand {
  /// Creates a navigation command.
  const NavigateCommand({
    required this.screen,
    this.settings = const {},
    this.language,
    this.theme,
    this.section,
  });

  /// Parses a navigation command.
  factory NavigateCommand.fromJson(Map<String, dynamic> json) {
    final screen = json['screen'];
    if (screen is! String) {
      throw FormatException('navigate command requires a string screen');
    }
    return NavigateCommand(
      screen: screen,
      settings: _stringMap(json['settings']),
      language: json['language'] as String?,
      theme: _parseTheme(json['theme']),
      section: json['section'] as String?,
    );
  }

  /// Registered screen name to open.
  final String screen;

  /// Optional app settings passed to the prepare callback.
  final Map<String, String> settings;

  /// Optional UI language passed to the prepare callback.
  final String? language;

  /// Optional app theme to apply before opening the screen.
  final Brightness? theme;

  /// Optional registered section to scroll into view after opening the screen.
  final String? section;
}

/// Captures a still of the screen currently displayed by the app.
final class ScreenshotCommand extends LiveCommand {
  /// Creates a screenshot command.
  const ScreenshotCommand({
    required this.name,
    this.pixelRatio = 1.0,
    this.full = false,
  });

  /// Parses a screenshot command.
  factory ScreenshotCommand.fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    if (name is! String) {
      throw FormatException('screenshot command requires a string name');
    }
    return ScreenshotCommand(
      name: name,
      pixelRatio: (json['pixel_ratio'] as num? ?? 1).toDouble(),
      full: json['full'] == true,
    );
  }

  /// Name to associate with the captured still.
  final String name;

  /// Pixel ratio for the captured still.
  final double pixelRatio;

  /// Whether to capture the full scrollable content.
  final bool full;
}

/// Restores the app to its initial state.
final class ResetCommand extends LiveCommand {
  /// Creates a reset command.
  const ResetCommand({this.settings = const {}, this.language});

  /// Parses a reset command.
  factory ResetCommand.fromJson(Map<String, dynamic> json) => ResetCommand(
    settings: _stringMap(json['settings']),
    language: json['language'] as String?,
  );

  /// Optional app settings passed to the prepare callback.
  final Map<String, String> settings;

  /// Optional UI language passed to the prepare callback.
  final String? language;
}

Map<String, String> _stringMap(Object? raw) => raw is Map
    ? raw.map((k, v) => MapEntry(k.toString(), v.toString()))
    : const {};

Brightness? _parseTheme(Object? raw) {
  if (raw == null) return null;
  if (raw == 'dark') return Brightness.dark;
  if (raw == 'light') return Brightness.light;
  throw FormatException('theme must be "dark" or "light", got $raw');
}
