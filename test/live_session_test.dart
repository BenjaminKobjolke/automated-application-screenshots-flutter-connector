import 'dart:convert';
import 'dart:io';

import 'package:automated_screenshot_connector/automated_screenshot_connector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/demo_server.dart';
import 'demo_host_test.dart' show capturePlatformCalls, pumpUntil;

void main() {
  silenceLogger();

  testWidgets('lists screens and navigates after preparing the app', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final server = await bindLoopback();
      final accepted = server.first;
      final navigatorKey = GlobalKey<NavigatorState>();
      final calls = <String>[];
      final screens = LiveScreenRegistry()
        ..add([
          LiveScreen(
            name: 'details',
            description: 'Details page',
            needsLogin: true,
            open: () async {
              calls.add('open');
              navigatorKey.currentState!.pushReplacement(
                MaterialPageRoute<void>(builder: (_) => const Text('Details')),
              );
            },
          ),
        ]);

      await tester.pumpWidget(
        AutomationDemoHost(
          host: '$loopbackHost:${server.port}',
          registry: DemoRegistry(),
          screens: screens,
          onPrepare: (settings, language) async {
            calls.add('prepare:${settings['account']}:$language');
          },
          child: MaterialApp(
            navigatorKey: navigatorKey,
            home: const Scaffold(body: Text('Home')),
          ),
        ),
      );
      final connection = await accepted;

      final listed = await sendAndRead(tester, connection, {
        'command': 'list_screens',
      });
      expect(listed, {
        'event': 'screens',
        'screens': [
          {
            'name': 'details',
            'description': 'Details page',
            'needs_login': true,
          },
        ],
      });

      final navigated = await sendAndRead(tester, connection, {
        'command': 'navigate',
        'screen': 'details',
        'settings': {'account': 'test'},
        'language': 'de',
      });
      expect(navigated, {'event': 'navigated', 'screen': 'details'});
      expect(calls, ['prepare:test:de', 'open']);
      expect(find.text('Details'), findsOneWidget);

      await connection.close();
      await server.close();
    });
  });

  testWidgets('captures a settled screen and resets through onPrepare', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final server = await bindLoopback();
      final accepted = server.first;
      var prepares = 0;
      await tester.pumpWidget(
        AutomationDemoHost(
          host: '$loopbackHost:${server.port}',
          registry: DemoRegistry(),
          screens: LiveScreenRegistry(),
          onPrepare: (_, __) async => prepares++,
          child: const MaterialApp(home: Scaffold(body: Text('Ready'))),
        ),
      );
      final connection = await accepted;

      final screenshot = await sendAndRead(tester, connection, {
        'command': 'screenshot',
        'name': 'ready',
      });
      final png = base64Decode(screenshot['png'] as String);
      expect(screenshot['event'], 'screenshot');
      expect(screenshot['name'], 'ready');
      expect(png.sublist(0, 4), [0x89, 0x50, 0x4e, 0x47]);

      expect(await sendAndRead(tester, connection, {'command': 'reset'}), {
        'event': 'reset_done',
      });
      expect(prepares, 1);

      await connection.close();
      await server.close();
    });
  });

  testWidgets('an unknown screen errors and the connection remains usable', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final server = await bindLoopback();
      final accepted = server.first;
      await tester.pumpWidget(
        AutomationDemoHost(
          host: '$loopbackHost:${server.port}',
          registry: DemoRegistry(),
          screens: LiveScreenRegistry()
            ..add([
              const LiveScreen(
                name: 'home',
                description: 'Home',
                needsLogin: false,
                open: _noop,
              ),
            ]),
          child: const MaterialApp(home: Text('Home')),
        ),
      );
      final connection = await accepted;

      final failure = await sendAndRead(tester, connection, {
        'command': 'navigate',
        'screen': 'missing',
      });
      expect(failure['event'], 'error');
      expect(failure['message'], contains('available: home'));
      expect(
        await sendAndRead(tester, connection, {'command': 'list_screens'}),
        {
          'event': 'screens',
          'screens': [
            {'name': 'home', 'description': 'Home', 'needs_login': false},
          ],
        },
      );

      await connection.close();
      await server.close();
    });
  });

  testWidgets('a start command still runs after live commands on one link', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final server = await bindLoopback();
      final accepted = server.first;
      await tester.pumpWidget(
        AutomationDemoHost(
          host: '$loopbackHost:${server.port}',
          registry: DemoRegistry()
            ..add([const DemoScript(id: 1, name: 'noop', steps: [])]),
          screens: LiveScreenRegistry(),
          child: const MaterialApp(home: Text('Home')),
        ),
      );
      final connection = await accepted;

      expect(
        await sendAndRead(tester, connection, {'command': 'list_screens'}),
        {'event': 'screens', 'screens': []},
      );
      final started = sendAndRead(tester, connection, {
        'command': 'start',
        'demo': 1,
      });
      expect(await started, {'event': 'demo_started', 'demo': 1});
      expect(await nextEvent(connection), {'event': 'demo_ended', 'demo': 1});

      await connection.close();
      await server.close();
    });
  });

  testWidgets('disconnect after a live command restores without closing app', (
    tester,
  ) async {
    final platformCalls = capturePlatformCalls(tester);
    final restored = <bool>[];
    await tester.runAsync(() async {
      final server = await bindLoopback();
      final accepted = server.first;
      await tester.pumpWidget(
        AutomationDemoHost(
          host: '$loopbackHost:${server.port}',
          registry: DemoRegistry(),
          screens: LiveScreenRegistry(),
          onRestore: () async => restored.add(true),
          child: const MaterialApp(home: Text('Home')),
        ),
      );
      final connection = await accepted;
      await sendAndRead(tester, connection, {'command': 'list_screens'});
      await connection.close();
      await pumpUntil(tester, () => restored.isNotEmpty);
      await server.close();
    });

    expect(restored, [true]);
    expect(platformCalls, isNot(contains('SystemNavigator.pop')));
  });
}

Future<void> _noop() async {}
