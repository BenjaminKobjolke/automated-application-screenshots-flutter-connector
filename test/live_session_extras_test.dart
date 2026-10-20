import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:automated_screenshot_connector/automated_screenshot_connector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/demo_server.dart';

void main() {
  silenceLogger();

  testWidgets('theme hook runs between prepare and opening the screen', (
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
            description: 'Details',
            needsLogin: false,
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
          onPrepare: (_, __) async => calls.add('prepare'),
          onSetTheme: (brightness) async => calls.add('theme:$brightness'),
          child: MaterialApp(
            navigatorKey: navigatorKey,
            home: const Scaffold(body: Text('Home')),
          ),
        ),
      );
      final connection = await accepted;

      expect(
        await sendAndRead(tester, connection, {
          'command': 'navigate',
          'screen': 'details',
          'theme': 'dark',
        }),
        {'event': 'navigated', 'screen': 'details'},
      );
      expect(calls, ['prepare', 'theme:Brightness.dark', 'open']);

      await connection.close();
      await server.close();
    });
  });

  testWidgets(
    'theme without a hook errors before prepare and connection works',
    (tester) async {
      await tester.runAsync(() async {
        final server = await bindLoopback();
        final accepted = server.first;
        var prepares = 0;
        await tester.pumpWidget(
          AutomationDemoHost(
            host: '$loopbackHost:${server.port}',
            registry: DemoRegistry(),
            screens: LiveScreenRegistry()..add([_screen('home', () async {})]),
            onPrepare: (_, __) async => prepares++,
            child: const MaterialApp(home: Text('Home')),
          ),
        );
        final connection = await accepted;

        final error = await sendAndRead(tester, connection, {
          'command': 'navigate',
          'screen': 'home',
          'theme': 'dark',
        });
        expect(error['event'], 'error');
        expect(error['message'], contains('no onSetTheme hook'));
        expect(prepares, 0);
        expect(
          await sendAndRead(tester, connection, {'command': 'list_screens'}),
          {
            'event': 'screens',
            'screens': [_screen('home', () async {}).toJson()],
          },
        );

        await connection.close();
        await server.close();
      });
    },
  );

  testWidgets('navigate scrolls a registered section into view', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final server = await bindLoopback();
      final accepted = server.first;
      final navigatorKey = GlobalKey<NavigatorState>();
      final sectionKey = GlobalKey();
      final screens = LiveScreenRegistry()
        ..add([
          LiveScreen(
            name: 'long',
            description: 'Long screen',
            needsLogin: false,
            sections: {'bottom': sectionKey},
            open: () async {
              navigatorKey.currentState!.pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    body: SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 1000),
                          Text('Bottom', key: sectionKey),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ]);
      await tester.pumpWidget(
        AutomationDemoHost(
          host: '$loopbackHost:${server.port}',
          registry: DemoRegistry(),
          screens: screens,
          child: MaterialApp(
            navigatorKey: navigatorKey,
            home: const Scaffold(body: Text('Home')),
          ),
        ),
      );
      final connection = await accepted;

      expect(
        await sendAndRead(tester, connection, {
          'command': 'navigate',
          'screen': 'long',
          'section': 'bottom',
        }),
        {'event': 'navigated', 'screen': 'long'},
      );
      expect(tester.getTopLeft(find.byKey(sectionKey)).dy, lessThan(600));
      expect(
        tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
        greaterThan(0),
      );

      await connection.close();
      await server.close();
    });
  });

  testWidgets('full capture expands content and restores viewport size', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final server = await bindLoopback();
      final accepted = server.first;
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        AutomationDemoHost(
          host: '$loopbackHost:${server.port}',
          registry: DemoRegistry(),
          screens: LiveScreenRegistry()
            ..add([
              _screen('long', () async {
                navigatorKey.currentState!.pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(
                      body: SingleChildScrollView(
                        child: SizedBox(height: 1500, child: Text('Long')),
                      ),
                    ),
                  ),
                );
              }),
            ]),
          child: MaterialApp(
            navigatorKey: navigatorKey,
            home: const Scaffold(body: Text('Home')),
          ),
        ),
      );
      final connection = await accepted;
      await sendAndRead(tester, connection, {
        'command': 'navigate',
        'screen': 'long',
      });

      final viewport = await _captureHeight(tester, connection, full: false);
      final full = await _captureHeight(tester, connection, full: true);
      final restored = await _captureHeight(tester, connection, full: false);
      expect(full, greaterThan(viewport));
      expect(restored, viewport);

      await connection.close();
      await server.close();
    });
  });

  testWidgets('full capture on a non-scrollable screen stays viewport sized', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final server = await bindLoopback();
      final accepted = server.first;
      await tester.pumpWidget(
        AutomationDemoHost(
          host: '$loopbackHost:${server.port}',
          registry: DemoRegistry(),
          screens: LiveScreenRegistry()..add([_screen('home', () async {})]),
          child: const MaterialApp(home: Scaffold(body: Text('Home'))),
        ),
      );
      final connection = await accepted;

      final viewport = await _captureHeight(tester, connection, full: false);
      final full = await _captureHeight(tester, connection, full: true);
      expect(full, viewport);

      await connection.close();
      await server.close();
    });
  });
}

LiveScreen _screen(String name, Future<void> Function() open) =>
    LiveScreen(name: name, description: name, needsLogin: false, open: open);

Future<int> _captureHeight(
  WidgetTester tester,
  Socket connection, {
  required bool full,
}) async {
  final event = await sendAndRead(tester, connection, {
    'command': 'screenshot',
    'name': 'capture',
    'full': full,
  });
  final bytes = base64Decode(event['png'] as String);
  return ByteData.sublistView(bytes).getUint32(20);
}
