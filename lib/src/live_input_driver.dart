import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'live_gesture.dart';
import 'live_input.dart';
import 'live_key_press.dart';
import 'protocol_events.dart';
import 'step_executor.dart';
import 'visible_text.dart';

/// Executes validated live input requests against the current app view.
final class LiveInputDriver {
  /// Creates an input driver with the app's existing gesture and step drivers.
  const LiveInputDriver({
    required this.steps,
    required this.reader,
    required this.gestures,
    required this.devicePixelRatio,
  });

  /// Performs existing keyed taps and focused text entry.
  final StepExecutor steps;

  /// Reads text exposed by Flutter semantics.
  final VisibleTextReader reader;

  /// Sends taps through the app's gesture recognizers.
  final GestureDriver gestures;

  /// Device pixel ratio for the render view's semantics coordinates.
  final double devicePixelRatio;

  /// Runs [input] relative to the current global logical-coordinate [view].
  Future<Map<String, Object>> handle(LiveInput input, Rect view) async {
    switch (input) {
      case ReadTextInput():
        await _settle();
        return DemoEvents.visibleText(
          reader.read(view, devicePixelRatio: devicePixelRatio),
        );
      case TapTextInput():
        final target = pickTarget(
          reader.read(view, devicePixelRatio: devicePixelRatio),
          input.text,
          input.match,
          input.index,
        );
        await _tap(target);
        await _settle();
        return DemoEvents.textTapped(input.text);
      case TapKeyInput():
        await steps.tap(input.key);
        await _settle();
        return DemoEvents.keyTapped(input.key);
      case TypeTextInput():
        if (input.field case final field?) {
          final target = _pickField(
            reader.read(view, devicePixelRatio: devicePixelRatio),
            field,
          );
          await _tap(target);
          await _settle();
        }
        await steps.typeText(input.text);
        await _settle();
        return DemoEvents.textTyped(input.text);
      case PressKeyInput():
        await const KeyPresser().press(input.key);
        await _settle();
        return DemoEvents.keyPressed(input.key);
    }
  }

  Future<void> _tap(VisibleTextEntry target) => gestures.perform(
    const LiveGesture(
      kind: GestureKind.tap,
      duration: Duration(milliseconds: 100),
      at: Offset(0.5, 0.5),
    ),
    target.rect,
  );

  VisibleTextEntry _pickField(List<VisibleTextEntry> entries, String field) {
    final candidates = entries
        .where(
          (entry) =>
              entry.kind == VisibleTextKind.textField &&
              (entry.label == field || entry.hint == field),
        )
        .toList();
    if (candidates.isEmpty) {
      throw StateError(
        'no visible text field has label or hint "$field"; fields: '
        '${_fieldCandidates(entries)}',
      );
    }
    if (candidates.length > 1) {
      throw StateError(
        '${candidates.length} text fields have label or hint "$field": '
        '${_fieldCandidates(candidates)}',
      );
    }
    return candidates.single;
  }
}

/// Picks the unique visible entry matching the request, or [index] among matches.
VisibleTextEntry pickTarget(
  List<VisibleTextEntry> entries,
  String text,
  TextMatch match,
  int? index,
) {
  final matching = entries.where((entry) => _matches(entry, text, match));
  final matches = matching.toList();
  if (matches.isEmpty) {
    throw StateError(
      'no visible control shows "$text"; visible: ${_entryCandidates(entries)}',
    );
  }

  final tappable = matches
      .where((entry) => entry.kind != VisibleTextKind.text)
      .toList();
  final candidates = tappable.isEmpty ? matches : tappable;
  if (index != null) {
    if (index >= candidates.length) {
      throw StateError(
        'index $index is out of range for ${candidates.length} controls '
        'matching "$text"; candidates: ${_entryCandidates(candidates)}',
      );
    }
    return candidates[index];
  }
  if (candidates.length > 1) {
    throw StateError(
      '${candidates.length} controls show "$text": '
      '${_entryCandidates(candidates)}; send index',
    );
  }
  return candidates.single;
}

bool _matches(VisibleTextEntry entry, String text, TextMatch match) {
  final values = [entry.text, entry.label, entry.hint].whereType<String>();
  return values.any(
    (value) => switch (match) {
      TextMatch.exact => value == text,
      TextMatch.contains => value.contains(text),
    },
  );
}

String _entryCandidates(List<VisibleTextEntry> entries) => entries
    .map((entry) => '"${entry.text}" ${entry.kind.wireName} at ${entry.bounds}')
    .join(', ');

String _fieldCandidates(List<VisibleTextEntry> entries) => entries
    .where((entry) => entry.kind == VisibleTextKind.textField)
    .map((entry) => '"${entry.label ?? entry.hint ?? entry.text}"')
    .join(', ');

Future<void> _settle() => WidgetsBinding.instance.endOfFrame;
