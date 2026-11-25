import 'dart:convert';
import 'dart:typed_data';

import 'package:automated_screenshot_connector/automated_screenshot_connector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/demo_server.dart';

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
          onPrepare: (_, _) async => prepares++,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(height: 1500, child: Text('Ready')),
              ),
            ),
          ),
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

      final viewportHeight = _pngHeight(png);
      final full = await sendAndRead(tester, connection, {
        'command': 'screenshot',
        'name': 'full',
        'full': true,
      });
      expect(
        _pngHeight(base64Decode(full['png'] as String)),
        greaterThan(viewportHeight),
      );
      final failure = await sendAndRead(tester, connection, {
        'command': 'screenshot',
        'name': 'invalid',
        'full': true,
        'pixel_ratio': 0,
      });
      expect(failure['event'], 'error');
      final restored = await sendAndRead(tester, connection, {
        'command': 'screenshot',
        'name': 'restored',
      });
      expect(
        _pngHeight(base64Decode(restored['png'] as String)),
        viewportHeight,
      );

      expect(await sendAndRead(tester, connection, {'command': 'reset'}), {
        'event': 'reset_done',
      });
      expect(prepares, 1);

      await connection.close();
      await server.close();
    });
  });
}

int _pngHeight(Uint8List png) => ByteData.sublistView(png).getUint32(20);
