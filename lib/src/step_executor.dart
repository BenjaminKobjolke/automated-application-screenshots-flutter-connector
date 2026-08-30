import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'registry.dart';
import 'steps.dart';
import 'still_capture.dart';

/// Receives each still the executor captured.
typedef StillSink = void Function(String name, Uint8List png);

/// Plays [DemoStep]s against the live widget tree, one after the other.
///
/// Taps are synthesized pointer events on the widget carrying the step's
/// `ValueKey`, so the app's own gesture handling runs unchanged; typing goes
/// into the focused `EditableText` char by char.
class StepExecutor {
  /// Creates an executor; [actions] resolves `custom` steps.
  StepExecutor({
    required this.still,
    required this.onStill,
    required this.actions,
  });

  /// Captures stills for `screenshot` steps.
  final StillCapture still;

  /// Where captured stills go (the demo host sends them to the tool).
  final StillSink onStill;

  /// App-registered callbacks for `custom` steps.
  final Map<String, CustomAction> actions;

  /// Plays [steps] in order; stills are rendered at [pixelRatio].
  ///
  /// Throws [StateError] when a key, focused field or action is missing, so
  /// the host can report it as an `error` event instead of recording a demo
  /// that silently skipped a step.
  Future<void> run(List<DemoStep> steps, {double pixelRatio = 1.0}) async {
    for (final step in steps) {
      switch (step) {
        case TapStep():
          await tap(step.key);
        case TypeTextStep():
          await typeText(step.text, charDelayMs: step.charDelayMs);
        case PauseStep():
          await _delay((step.seconds * 1000).round());
        case ScreenshotStep():
          await _delay(screenshotSettleMs);
          onStill(step.name, await still.capture(pixelRatio));
        case CustomStep():
          final action = actions[step.name] ??
              (throw StateError('no custom action named "${step.name}"'));
          await action();
      }
    }
  }

  /// Taps the centre of the widget keyed `ValueKey(key)`.
  Future<void> tap(String key) async {
    final box = _findByKey(key).findRenderObject();
    if (box is! RenderBox || !box.hasSize) {
      throw StateError('widget "$key" has no size to tap');
    }
    final center = box.localToGlobal(box.size.center(Offset.zero));
    final binding = GestureBinding.instance;
    binding.handlePointerEvent(PointerDownEvent(position: center));
    await _delay(defaultCharDelayMs);
    binding.handlePointerEvent(PointerUpEvent(position: center));
    await _delay(defaultCharDelayMs);
  }

  /// Appends [text] to the focused text field, one char per [charDelayMs].
  Future<void> typeText(String text,
      {int charDelayMs = defaultCharDelayMs}) async {
    final state = FocusManager.instance.primaryFocus?.context
        ?.findAncestorStateOfType<EditableTextState>();
    if (state == null) throw StateError('type_text: no text field has focus');
    for (final rune in text.runes) {
      final current = state.textEditingValue.text;
      final next = current + String.fromCharCode(rune);
      state.userUpdateTextEditingValue(
        TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        ),
        SelectionChangedCause.keyboard,
      );
      await _delay(charDelayMs);
    }
  }

  Element _findByKey(String key) {
    final wanted = ValueKey<String>(key);
    Element? found;
    void visit(Element element) {
      if (found != null) return;
      if (element.widget.key == wanted) {
        found = element;
        return;
      }
      element.visitChildren(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(visit);
    return found ?? (throw StateError('no widget with ValueKey("$key")'));
  }

  Future<void> _delay(int ms) => Future<void>.delayed(Duration(milliseconds: ms));
}
