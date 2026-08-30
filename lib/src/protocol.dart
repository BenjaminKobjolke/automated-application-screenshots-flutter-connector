import 'dart:convert';
import 'dart:typed_data';

import 'steps.dart';

/// The tool's `start` command: which demo to play and how.
class StartCommand {
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
    if (json['command'] != 'start' || json['demo'] is! int) {
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
                DemoStep.fromJson(Map<String, dynamic>.from(s as Map))
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

  static Map<String, String> _stringMap(Object? raw) => raw is Map
      ? raw.map((k, v) => MapEntry(k.toString(), v.toString()))
      : const {};
}

/// Encoders for the events the app reports back to the tool.
class DemoEvents {
  DemoEvents._();

  /// Playing begins.
  static Map<String, Object> demoStarted(int demo) =>
      {'event': 'demo_started', 'demo': demo};

  /// A still captured in-app, PNG bytes inline.
  static Map<String, Object> screenshot(String name, Uint8List png) =>
      {'event': 'screenshot', 'name': name, 'png': base64Encode(png)};

  /// Playing finished.
  static Map<String, Object> demoEnded(int demo) =>
      {'event': 'demo_ended', 'demo': demo};

  /// Header announcing [size] raw mp4 bytes that follow immediately.
  static Map<String, Object> videoHeader(int demo, int size) =>
      {'event': 'video', 'demo': demo, 'size': size};

  /// Something went wrong; the tool fails this run.
  static Map<String, Object> error(String message) =>
      {'event': 'error', 'message': message};
}
