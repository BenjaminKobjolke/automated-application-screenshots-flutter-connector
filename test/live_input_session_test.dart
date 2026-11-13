import 'dart:io';

import 'package:automated_screenshot_connector/automated_screenshot_connector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/demo_server.dart';

void main() {
  silenceLogger();

  testWidgets('reads visible text and excludes modal and off-screen content', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final server = await bindLoopback();
      final accepted = server.first;
      final controller = TextEditingController(text: 'person@example.com');
      await tester.pumpWidget(
        _host(server, _InputPage(controller: controller)),
      );
      final connection = await accepted;

      final response = await sendAndRead(tester, connection, {
        'command': 'read_text',
      });
      expect(response['event'], 'visible_text');
      final entries = (response['entries'] as List).cast<Map>();
      final title = entries.singleWhere((entry) => entry['text'] == 'Inbox');
      final enabled = entries.singleWhere(
        (entry) => entry['text'] == 'Enabled action',
      );
      final disabled = entries.singleWhere(
        (entry) => entry['text'] == 'Disabled action',
      );
      final field = entries.singleWhere((entry) => entry['label'] == 'Email');
      expect(title['kind'], 'text');
      expect(enabled['kind'], 'button');
      expect(enabled['enabled'], isTrue);
      expect(disabled['enabled'], isFalse);
      expect(field['label'], 'Email');
      expect(field['value'], 'person@example.com');
      expect(field['bounds'], hasLength(4));
      expect(
        (field['bounds'] as List).every((value) => value >= 0 && value <= 1),
        isTrue,
      );
      expect(entries.any((entry) => entry['text'] == 'Item 99'), isFalse);

      await sendAndRead(tester, connection, {
        'command': 'tap_text',
        'text': 'Open dialog',
      });
      final modal = await sendAndRead(tester, connection, {
        'command': 'read_text',
      });
      final modalTexts = (modal['entries'] as List)
          .map((entry) => (entry as Map)['text'])
          .toList();
      expect(modalTexts, contains('Dialog content'));
      expect(modalTexts, isNot(contains('Inbox')));

      await connection.close();
      await server.close();
      controller.dispose();
    });
  });

  testWidgets(
    'taps by text and key, types into fields, and reuses connection',
    (tester) async {
      await tester.runAsync(() async {
        final server = await bindLoopback();
        final accepted = server.first;
        final controller = TextEditingController();
        final emailFocus = FocusNode();
        final passwordFocus = FocusNode();
        var taps = 0;
        await tester.pumpWidget(
          _host(
            server,
            _InputPage(
              controller: controller,
              emailFocus: emailFocus,
              passwordFocus: passwordFocus,
              onSave: () => taps++,
            ),
          ),
        );
        final connection = await accepted;

        expect(
          await sendAndRead(tester, connection, {
            'command': 'tap_text',
            'text': 'Save',
            'match': 'contains',
            'index': 1,
          }),
          {'event': 'text_tapped', 'text': 'Save'},
        );
        expect(taps, 1);
        final ambiguous = await sendAndRead(tester, connection, {
          'command': 'tap_text',
          'text': 'Save',
          'match': 'contains',
        });
        expect(ambiguous['event'], 'error');
        expect(ambiguous['message'], contains('index'));
        expect(ambiguous['message'], contains('Save changes'));
        expect(
          await sendAndRead(tester, connection, {
            'command': 'tap_key',
            'key': 'go',
          }),
          {'event': 'key_tapped', 'key': 'go'},
        );
        expect(taps, 2);

        final unfocused = await sendAndRead(tester, connection, {
          'command': 'type_text',
          'text': 'ignored',
        });
        expect(unfocused['event'], 'error');
        expect(unfocused['message'], contains('no text field has focus'));

        expect(
          await sendAndRead(tester, connection, {
            'command': 'type_text',
            'text': 'hello',
            'field': 'Email',
          }),
          {'event': 'text_typed', 'text': 'hello'},
        );
        expect(controller.text, 'hello');
        await sendAndRead(tester, connection, {
          'command': 'press_key',
          'key': 'arrow_left',
        });
        await sendAndRead(tester, connection, {
          'command': 'type_text',
          'text': 'X',
        });
        expect(controller.text, 'hellXo');
        await sendAndRead(tester, connection, {
          'command': 'press_key',
          'key': 'tab',
        });
        expect(passwordFocus.hasFocus, isTrue);
        await sendAndRead(tester, connection, {
          'command': 'press_key',
          'key': 'shift_tab',
        });
        expect(emailFocus.hasFocus, isTrue);
        expect(
          await sendAndRead(tester, connection, {
            'command': 'press_key',
            'key': 'backspace',
          }),
          {'event': 'key_pressed', 'key': 'backspace'},
        );
        expect(controller.text, 'hello');

        await connection.close();
        await server.close();
        controller.dispose();
        emailFocus.dispose();
        passwordFocus.dispose();
      });
    },
  );

  testWidgets('presses enter in a field and escape closes a dialog', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final server = await bindLoopback();
      final accepted = server.first;
      final controller = TextEditingController();
      var submitted = '';
      await tester.pumpWidget(
        _host(
          server,
          _InputPage(
            controller: controller,
            onSubmitted: (value) => submitted = value,
          ),
        ),
      );
      final connection = await accepted;

      await sendAndRead(tester, connection, {
        'command': 'type_text',
        'text': 'ready',
        'field': 'Email',
      });
      expect(
        await sendAndRead(tester, connection, {
          'command': 'press_key',
          'key': 'enter',
        }),
        {'event': 'key_pressed', 'key': 'enter'},
      );
      expect(submitted, 'ready');

      await sendAndRead(tester, connection, {
        'command': 'tap_text',
        'text': 'Open dialog',
      });
      expect(find.text('Dialog content'), findsOneWidget);
      await sendAndRead(tester, connection, {
        'command': 'press_key',
        'key': 'escape',
      });
      await tester.pumpAndSettle();
      expect(find.text('Dialog content'), findsNothing);

      await connection.close();
      await server.close();
      controller.dispose();
    });
  });
}

AutomationDemoHost _host(ServerSocket server, Widget child) =>
    AutomationDemoHost(
      host: '$loopbackHost:${server.port}',
      registry: DemoRegistry(),
      screens: LiveScreenRegistry(),
      exitWhenDone: false,
      child: MaterialApp(home: Scaffold(body: child)),
    );

class _InputPage extends StatelessWidget {
  const _InputPage({
    required this.controller,
    this.emailFocus,
    this.passwordFocus,
    this.onSave,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode? emailFocus;
  final FocusNode? passwordFocus;
  final VoidCallback? onSave;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Text('Inbox'),
      ElevatedButton(onPressed: onSave ?? () {}, child: const Text('Save')),
      ElevatedButton(
        onPressed: onSave ?? () {},
        child: const Text('Save changes'),
      ),
      ElevatedButton(
        key: const ValueKey('go'),
        onPressed: onSave ?? () {},
        child: const Text('Enabled action'),
      ),
      const ElevatedButton(onPressed: null, child: Text('Disabled action')),
      TextField(
        controller: controller,
        focusNode: emailFocus,
        decoration: const InputDecoration(labelText: 'Email'),
        onSubmitted: onSubmitted,
      ),
      TextField(
        focusNode: passwordFocus,
        decoration: const InputDecoration(labelText: 'Password'),
      ),
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => const AlertDialog(content: Text('Dialog content')),
          ),
          child: const Text('Open dialog'),
        ),
      ),
      Expanded(
        child: ListView.builder(
          itemCount: 100,
          itemBuilder: (_, index) => Text('Item $index'),
        ),
      ),
    ],
  );
}
