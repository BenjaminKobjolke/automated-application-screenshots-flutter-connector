import 'package:automated_screenshot_connector/automated_screenshot_connector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/demo_server.dart';

void main() {
  silenceLogger();

  testWidgets('set_theme applies theme without preparing and replies', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final server = await bindLoopback();
      final accepted = server.first;
      final themes = <Brightness>[];
      var prepares = 0;
      await tester.pumpWidget(
        AutomationDemoHost(
          host: '$loopbackHost:${server.port}',
          registry: DemoRegistry(),
          screens: LiveScreenRegistry()..add([_screen()]),
          onPrepare: (_, __) async => prepares++,
          onSetTheme: (theme) async => themes.add(theme),
          child: const MaterialApp(home: Text('Home')),
        ),
      );
      final connection = await accepted;

      expect(
        await sendAndRead(tester, connection, {
          'command': 'set_theme',
          'theme': 'dark',
        }),
        {'event': 'theme_set', 'theme': 'dark'},
      );
      expect(themes, [Brightness.dark]);
      expect(prepares, 0);

      await connection.close();
      await server.close();
    });
  });

  testWidgets('set_theme without a hook errors and keeps connection usable', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final server = await bindLoopback();
      final accepted = server.first;
      await tester.pumpWidget(
        AutomationDemoHost(
          host: '$loopbackHost:${server.port}',
          registry: DemoRegistry(),
          screens: LiveScreenRegistry()..add([_screen()]),
          child: const MaterialApp(home: Text('Home')),
        ),
      );
      final connection = await accepted;

      final error = await sendAndRead(tester, connection, {
        'command': 'set_theme',
        'theme': 'dark',
      });
      expect(error['event'], 'error');
      expect(error['message'], contains('no onSetTheme hook'));
      expect(
        await sendAndRead(tester, connection, {'command': 'list_screens'}),
        {
          'event': 'screens',
          'screens': [_screen().toJson()],
        },
      );

      await connection.close();
      await server.close();
    });
  });
}

LiveScreen _screen() => LiveScreen(
  name: 'home',
  description: 'Home',
  needsLogin: false,
  open: () async {},
);
