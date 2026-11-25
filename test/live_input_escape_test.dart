import 'package:automated_screenshot_connector/automated_screenshot_connector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/demo_server.dart';

void main() {
  silenceLogger();

  testWidgets('escape pops a route when no widget handles it', (tester) async {
    await tester.runAsync(() async {
      final server = await bindLoopback();
      final accepted = server.first;
      NavigatorState? navigator;
      await tester.pumpWidget(
        AutomationDemoHost(
          host: '$loopbackHost:${server.port}',
          registry: DemoRegistry(),
          screens: LiveScreenRegistry(),
          exitWhenDone: false,
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                navigator = Navigator.of(context);
                return const Scaffold(body: Text('First page'));
              },
            ),
          ),
        ),
      );
      final connection = await accepted;

      navigator!.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Second page')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Second page'), findsOneWidget);

      await sendAndRead(tester, connection, {
        'command': 'press_key',
        'key': 'escape',
      });
      await tester.pumpAndSettle();

      expect(find.text('Second page'), findsNothing);
      expect(find.text('First page'), findsOneWidget);

      await connection.close();
      await server.close();
    });
  });
}
