import 'package:automated_screenshot_connector/automated_screenshot_connector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/demo_server.dart';

void main() {
  silenceLogger();

  testWidgets('navigate passes the record id after prepare', (tester) async {
    await tester.runAsync(() async {
      final server = await bindLoopback();
      final accepted = server.first;
      final calls = <String>[];
      int? openedId;
      final screens = LiveScreenRegistry()
        ..add([
          LiveScreen(
            name: 'todo_detail',
            description: 'Todo detail',
            needsLogin: false,
            open: () async => calls.add('open newest'),
            record: LiveScreenRecord(
              meaning: 'todo id',
              open: (id) async {
                openedId = id;
                calls.add('open $id');
              },
            ),
          ),
        ]);
      await tester.pumpWidget(
        AutomationDemoHost(
          host: '$loopbackHost:${server.port}',
          registry: DemoRegistry(),
          screens: screens,
          onPrepare: (_, __) async {
            calls.add('prepare');
          },
          child: const MaterialApp(home: Text('Home')),
        ),
      );
      final connection = await accepted;

      expect(
        await sendAndRead(tester, connection, {
          'command': 'navigate',
          'screen': 'todo_detail',
          'record_id': 11551,
        }),
        {'event': 'navigated', 'screen': 'todo_detail'},
      );
      expect(openedId, 11551);
      expect(calls, ['prepare', 'open 11551']);

      await connection.close();
      await server.close();
    });
  });

  testWidgets('navigate without a record id uses the plain open callback', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final server = await bindLoopback();
      final accepted = server.first;
      var plainOpenCalled = false;
      final screens = LiveScreenRegistry()
        ..add([
          LiveScreen(
            name: 'todo_detail',
            description: 'Todo detail',
            needsLogin: false,
            open: () async => plainOpenCalled = true,
            record: LiveScreenRecord(meaning: 'todo id', open: (_) async {}),
          ),
        ]);
      await tester.pumpWidget(
        AutomationDemoHost(
          host: '$loopbackHost:${server.port}',
          registry: DemoRegistry(),
          screens: screens,
          child: const MaterialApp(home: Text('Home')),
        ),
      );
      final connection = await accepted;

      expect(
        await sendAndRead(tester, connection, {
          'command': 'navigate',
          'screen': 'todo_detail',
        }),
        {'event': 'navigated', 'screen': 'todo_detail'},
      );
      expect(plainOpenCalled, isTrue);

      await connection.close();
      await server.close();
    });
  });

  testWidgets(
    'unsupported record id errors before prepare and lists metadata',
    (tester) async {
      await tester.runAsync(() async {
        final server = await bindLoopback();
        final accepted = server.first;
        var prepares = 0;
        final plainScreen = LiveScreen(
          name: 'home',
          description: 'Home',
          needsLogin: false,
          open: () async {},
        );
        final recordScreen = LiveScreen(
          name: 'todo_detail',
          description: 'Todo detail',
          needsLogin: false,
          open: () async {},
          record: LiveScreenRecord(meaning: 'todo id', open: (_) async {}),
        );
        final screens = LiveScreenRegistry()..add([plainScreen, recordScreen]);
        await tester.pumpWidget(
          AutomationDemoHost(
            host: '$loopbackHost:${server.port}',
            registry: DemoRegistry(),
            screens: screens,
            onPrepare: (_, __) async {
              prepares++;
            },
            child: const MaterialApp(home: Text('Home')),
          ),
        );
        final connection = await accepted;

        final error = await sendAndRead(tester, connection, {
          'command': 'navigate',
          'screen': 'home',
          'record_id': 11551,
        });
        expect(error['event'], 'error');
        expect(error['message'], contains('takes no record id'));
        expect(prepares, 0);
        expect(
          await sendAndRead(tester, connection, {'command': 'list_screens'}),
          {
            'event': 'screens',
            'screens': [plainScreen.toJson(), recordScreen.toJson()],
          },
        );
        expect(plainScreen.toJson().containsKey('record_id'), isFalse);
        expect(recordScreen.toJson()['record_id'], 'todo id');

        await connection.close();
        await server.close();
      });
    },
  );
}
