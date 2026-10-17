import 'dart:convert';
import 'dart:typed_data';

import 'steps.dart';

/// Names used by the JSON-lines command and event protocol.
abstract final class ProtocolNames {
  /// The command that starts a demo.
  static const String start = 'start';

  /// The command that lists registered screens.
  static const String listScreens = 'list_screens';

  /// The command that opens a registered screen.
  static const String navigate = 'navigate';

  /// The command that captures the current screen.
  static const String screenshot = 'screenshot';

  /// The command that restores the app's initial state.
  static const String reset = 'reset';

  /// The event reporting registered screens.
  static const String screens = 'screens';

  /// The event confirming a screen navigation.
  static const String navigated = 'navigated';

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
    );
  }

  /// Registered screen name to open.
  final String screen;

  /// Optional app settings passed to the prepare callback.
  final Map<String, String> settings;

  /// Optional UI language passed to the prepare callback.
  final String? language;
}

/// Captures a still of the screen currently displayed by the app.
final class ScreenshotCommand extends LiveCommand {
  /// Creates a screenshot command.
  const ScreenshotCommand({required this.name, this.pixelRatio = 1.0});

  /// Parses a screenshot command.
  factory ScreenshotCommand.fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    if (name is! String) {
      throw FormatException('screenshot command requires a string name');
    }
    return ScreenshotCommand(
      name: name,
      pixelRatio: (json['pixel_ratio'] as num? ?? 1).toDouble(),
    );
  }

  /// Name to associate with the captured still.
  final String name;

  /// Pixel ratio for the captured still.
  final double pixelRatio;
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

/// Encoders for the events the app reports back to the tool.
class DemoEvents {
  DemoEvents._();

  /// Playing begins.
  static Map<String, Object> demoStarted(int demo) => {
    'event': ProtocolNames.demoStarted,
    'demo': demo,
  };

  /// A still captured in-app, PNG bytes inline.
  static Map<String, Object> screenshot(String name, Uint8List png) => {
    'event': ProtocolNames.screenshot,
    'name': name,
    'png': base64Encode(png),
  };

  /// Playing finished.
  static Map<String, Object> demoEnded(int demo) => {
    'event': ProtocolNames.demoEnded,
    'demo': demo,
  };

  /// Reports the app's registered screens.
  static Map<String, Object> screens(List<Map<String, Object>> screens) => {
    'event': ProtocolNames.screens,
    'screens': screens,
  };

  /// Confirms that [screen] has been opened.
  static Map<String, Object> navigated(String screen) => {
    'event': ProtocolNames.navigated,
    'screen': screen,
  };

  /// Confirms that the app has been reset.
  static Map<String, Object> resetDone() => {'event': ProtocolNames.resetDone};

  /// Header announcing [size] raw mp4 bytes that follow immediately.
  static Map<String, Object> videoHeader(int demo, int size) => {
    'event': ProtocolNames.video,
    'demo': demo,
    'size': size,
  };

  /// Something went wrong; the tool fails this run.
  static Map<String, Object> error(String message) => {
    'event': ProtocolNames.error,
    'message': message,
  };
}
