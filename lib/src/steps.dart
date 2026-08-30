/// Framework-free demo step model, shared by demos registered in the app and
/// steps the recording tool sends in its `start` command.
///
/// Mirrors the python connector's `steps.py`; the JSON shape is the wire
/// format documented in the tool's `docs/AUTOMATION_INTERFACE.md`.
library;

/// Delay between typed characters when a step does not set its own.
const int defaultCharDelayMs = 60;

/// Delay before a screenshot so the UI has settled from the previous action.
const int screenshotSettleMs = 400;

/// Delay after `onPrepare` before `demo_started`, so the first frame is stable.
const int startDelayMs = 500;

/// Hold on the final state before `demo_ended`, so the video does not cut off.
const int endHoldMs = 1000;

/// One scripted action of a demo.
sealed class DemoStep {
  const DemoStep();

  /// Parses one step object (`{"type": "tap", "key": "..."}`).
  ///
  /// Throws [FormatException] on an unknown type or a missing field.
  factory DemoStep.fromJson(Map<String, dynamic> json) {
    final type = json['type'];
    switch (type) {
      case 'tap':
        return TapStep(_string(json, 'key'));
      case 'type_text':
        return TypeTextStep(_string(json, 'text'),
            charDelayMs: (json['char_delay_ms'] as num?)?.toInt() ??
                defaultCharDelayMs);
      case 'pause':
        return PauseStep((json['seconds'] as num? ?? 0).toDouble());
      case 'screenshot':
        return ScreenshotStep(_string(json, 'name'));
      case 'custom':
        return CustomStep(_string(json, 'name'));
    }
    throw FormatException('unknown demo step type: $type');
  }

  /// The wire representation of this step.
  Map<String, dynamic> toJson();

  /// Milliseconds this step takes to play (for [estimatedDuration]).
  int get durationMs;

  static String _string(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String) {
      throw FormatException('step ${json['type']} needs a string "$key"');
    }
    return value;
  }
}

/// Tap the widget carrying `ValueKey(key)`.
final class TapStep extends DemoStep {
  /// Creates a tap on the widget keyed [key].
  const TapStep(this.key);

  /// The `ValueKey` value of the widget to tap.
  final String key;

  @override
  Map<String, dynamic> toJson() => {'type': 'tap', 'key': key};

  @override
  int get durationMs => defaultCharDelayMs;
}

/// Type [text] char by char into the focused text field, like a human.
final class TypeTextStep extends DemoStep {
  /// Creates a typing step; `{placeholder}`s are filled by [localizeScript].
  const TypeTextStep(this.text, {this.charDelayMs = defaultCharDelayMs});

  /// The text to type.
  final String text;

  /// Delay between characters.
  final int charDelayMs;

  @override
  Map<String, dynamic> toJson() =>
      {'type': 'type_text', 'text': text, 'char_delay_ms': charDelayMs};

  @override
  int get durationMs => text.length * charDelayMs;
}

/// Do nothing for [seconds] (reading time for viewers).
final class PauseStep extends DemoStep {
  /// Creates a pause of [seconds].
  const PauseStep(this.seconds);

  /// Pause length.
  final double seconds;

  @override
  Map<String, dynamic> toJson() => {'type': 'pause', 'seconds': seconds};

  @override
  int get durationMs => (seconds * 1000).round();
}

/// Capture a still named [name] and send it to the tool.
final class ScreenshotStep extends DemoStep {
  /// Creates a still request; [name] becomes `<name>.png`, never localized.
  const ScreenshotStep(this.name);

  /// Filename-friendly still name, unique within the demo.
  final String name;

  @override
  Map<String, dynamic> toJson() => {'type': 'screenshot', 'name': name};

  @override
  int get durationMs => screenshotSettleMs;
}

/// Run the app-registered callback named [name] (`DemoRegistry.customActions`).
final class CustomStep extends DemoStep {
  /// Creates a custom action step.
  const CustomStep(this.name);

  /// Name the app registered the callback under.
  final String name;

  @override
  Map<String, dynamic> toJson() => {'type': 'custom', 'name': name};

  @override
  int get durationMs => defaultCharDelayMs;
}

/// One playable demo: a stable id, an output-folder-friendly name, steps.
class DemoScript {
  /// Creates a demo script.
  const DemoScript({required this.id, required this.name, required this.steps});

  /// The id the tool's config refers to.
  final int id;

  /// Output folder name on the tool side.
  final String name;

  /// Steps in play order.
  final List<DemoStep> steps;
}

final _placeholder = RegExp(r'\{(\w+)\}');

/// Fills `{placeholder}`s in [TypeTextStep]s of [steps] from [texts].
///
/// Empty [texts] returns [steps] unchanged. Screenshot names are never
/// localized — they must stay stable filenames. Throws [ArgumentError] when a
/// placeholder has no text.
List<DemoStep> localizeSteps(List<DemoStep> steps, Map<String, String> texts) {
  if (texts.isEmpty) return steps;
  return [
    for (final step in steps)
      if (step is TypeTextStep)
        TypeTextStep(
          step.text.replaceAllMapped(_placeholder, (m) {
            final key = m[1]!;
            return texts[key] ??
                (throw ArgumentError(
                    'no text for placeholder {$key} (available: ${texts.keys.join(', ')})'));
          }),
          charDelayMs: step.charDelayMs,
        )
      else
        step,
  ];
}

/// Seconds the [steps] will take to play, without running them.
///
/// Includes the host's start delay and end hold, so a demo can be checked
/// against the tool's 300 s cap before spending a take on it.
double estimatedDuration(List<DemoStep> steps) {
  final delays = steps.fold<int>(0, (sum, s) => sum + s.durationMs);
  return (startDelayMs + delays + endHoldMs) / 1000;
}
