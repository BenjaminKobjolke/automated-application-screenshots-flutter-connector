import 'dart:ui';

import 'package:automated_screenshot_connector/automated_screenshot_connector.dart';
import 'package:automated_screenshot_connector/src/live_input.dart';
import 'package:automated_screenshot_connector/src/live_input_driver.dart';
import 'package:automated_screenshot_connector/src/protocol_events.dart';
import 'package:automated_screenshot_connector/src/visible_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LiveInput parsing', () {
    test('parses all input commands and their defaults', () {
      final readText = LiveInput.fromJson({'command': 'read_text'});
      final tapText = LiveInput.fromJson({
        'command': 'tap_text',
        'text': 'Sign in',
      });
      final tapKey = LiveInput.fromJson({
        'command': 'tap_key',
        'key': 'login_button',
      });
      final typeText = LiveInput.fromJson({
        'command': 'type_text',
        'text': 'me@x.de',
      });
      final pressKey = LiveInput.fromJson({
        'command': 'press_key',
        'key': 'shift_tab',
      });

      expect(readText, isA<ReadTextInput>());
      expect(tapText, isA<TapTextInput>());
      expect((tapText as TapTextInput).text, 'Sign in');
      expect(tapText.match, TextMatch.exact);
      expect(tapText.index, isNull);
      expect(tapKey, isA<TapKeyInput>());
      expect((tapKey as TapKeyInput).key, 'login_button');
      expect(typeText, isA<TypeTextInput>());
      expect((typeText as TypeTextInput).text, 'me@x.de');
      expect(typeText.field, isNull);
      expect(pressKey, isA<PressKeyInput>());
      expect((pressKey as PressKeyInput).key, LiveKey.shiftTab);
    });

    test('parses explicit text matching and field selection', () {
      final tapText = LiveInput.fromJson({
        'command': 'tap_text',
        'text': 'Save',
        'match': 'contains',
        'index': 1,
      }) as TapTextInput;
      final typeText = LiveInput.fromJson({
        'command': 'type_text',
        'text': 'hello',
        'field': 'Name',
      }) as TypeTextInput;

      expect(tapText.match, TextMatch.contains);
      expect(tapText.index, 1);
      expect(typeText.field, 'Name');
    });

    test('rejects missing or empty required text and key values', () {
      final invalid = <Map<String, Object?>>[
        {'command': 'tap_text'},
        {'command': 'tap_text', 'text': ''},
        {'command': 'tap_key'},
        {'command': 'tap_key', 'key': ''},
        {'command': 'type_text'},
        {'command': 'type_text', 'text': ''},
        {'command': 'press_key'},
        {'command': 'press_key', 'key': ''},
      ];

      for (final json in invalid) {
        expect(
          () => LiveInput.fromJson(json),
          throwsA(isA<FormatException>()),
          reason: '$json',
        );
      }
    });

    test('rejects invalid index, match and press key', () {
      final invalid = <Map<String, Object?>>[
        {'command': 'tap_text', 'text': 'Save', 'index': -1},
        {'command': 'tap_text', 'text': 'Save', 'index': 1.5},
        {'command': 'tap_text', 'text': 'Save', 'index': '1'},
        {'command': 'tap_text', 'text': 'Save', 'match': 'prefix'},
        {'command': 'press_key', 'key': 'super'},
      ];

      for (final json in invalid) {
        expect(
          () => LiveInput.fromJson(json),
          throwsA(isA<FormatException>()),
          reason: '$json',
        );
      }
    });
  });

  test('ToolCommand parses every live input wire name', () {
    final commands = <Map<String, Object?>>[
      {'command': 'read_text'},
      {'command': 'tap_text', 'text': 'Save'},
      {'command': 'tap_key', 'key': 'save'},
      {'command': 'type_text', 'text': 'hello'},
      {'command': 'press_key', 'key': 'enter'},
    ];

    for (final json in commands) {
      expect(ToolCommand.fromJson(json), isA<InputCommand>(), reason: '$json');
    }
  });

  group('pickTarget', () {
    final entries = <VisibleTextEntry>[
      _entry('Save', VisibleTextKind.button, left: 0.0),
      _entry('Save changes', VisibleTextKind.button, left: 0.1),
      _entry('Save draft', VisibleTextKind.button, left: 0.6),
      _entry('Save', VisibleTextKind.text, left: 0.4),
      _entry(
        'person@example.com',
        VisibleTextKind.textField,
        label: 'Email',
        hint: 'Work email',
        left: 0.2,
      ),
    ];

    test('matches exact or contains text and field metadata', () {
      expect(
        pickTarget(entries, 'Save changes', TextMatch.exact, null).text,
        'Save changes',
      );
      expect(
        pickTarget(entries, 'Save', TextMatch.contains, 1).text,
        'Save changes',
      );
      expect(
        pickTarget(entries, 'Work email', TextMatch.exact, null).label,
        'Email',
      );
    });

    test('prefers tappable entries over ordinary text', () {
      expect(
        pickTarget(entries, 'Save', TextMatch.exact, null).kind,
        VisibleTextKind.button,
      );
    });

    test('reports missing text with visible candidates', () {
      expect(
        () => pickTarget(entries, 'Cancel', TextMatch.exact, null),
        throwsA(
          isA<StateError>()
              .having((error) => error.message, 'message', contains('Cancel'))
              .having((error) => error.message, 'message', contains('Save'))
              .having(
                (error) => error.message,
                'message',
                contains('person@example.com'),
              ),
        ),
      );
    });

    test('reports ambiguous candidates and asks for an index', () {
      expect(
        () => pickTarget(entries, 'Save', TextMatch.contains, null),
        throwsA(
          isA<StateError>()
              .having((error) => error.message, 'message', contains('index'))
              .having(
                (error) => error.message,
                'message',
                contains('Save changes'),
              )
              .having(
                (error) => error.message,
                'message',
                contains('Save draft'),
              ),
        ),
      );
    });

    test('reports an out-of-range match index', () {
      expect(
        () => pickTarget(entries, 'Save', TextMatch.contains, 3),
        throwsA(
          isA<StateError>()
              .having((error) => error.message, 'message', contains('3'))
              .having((error) => error.message, 'message', contains('index')),
        ),
      );
    });
  });

  test('encodes each input reply with its documented shape', () {
    final entry = _entry('Sign in', VisibleTextKind.button, left: 0.1);

    expect(DemoEvents.visibleText([entry]), {
      'event': 'visible_text',
      'entries': [entry.toJson()],
    });
    expect(DemoEvents.textTapped('Sign in'), {
      'event': 'text_tapped',
      'text': 'Sign in',
    });
    expect(DemoEvents.keyTapped('login'), {
      'event': 'key_tapped',
      'key': 'login',
    });
    expect(DemoEvents.textTyped('hello'), {
      'event': 'text_typed',
      'text': 'hello',
    });
    expect(DemoEvents.keyPressed(LiveKey.shiftTab), {
      'event': 'key_pressed',
      'key': 'shift_tab',
    });
  });
}

VisibleTextEntry _entry(
  String text,
  VisibleTextKind kind, {
  String? label,
  String? hint,
  required double left,
}) => VisibleTextEntry(
  text: text,
  kind: kind,
  enabled: true,
  rect: Rect.fromLTWH(left, 0.1, 0.2, 0.1),
  view: Rect.fromLTWH(0, 0, 1, 1),
  label: label,
  hint: hint,
  value: kind == VisibleTextKind.textField ? text : null,
);
