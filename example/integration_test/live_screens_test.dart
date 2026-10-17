import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:live_screens_example/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('live commands open named screens and capture a PNG', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final accepted = server.first;

      await tester.pumpWidget(
        LiveScreensExample(host: '127.0.0.1:${server.port}'),
      );
      final connection = await accepted;
      final events = StreamIterator<String>(
        connection
            .cast<List<int>>()
            .transform(utf8.decoder)
            .transform(const LineSplitter()),
      );

      Future<Map<String, dynamic>> send(Map<String, Object?> command) async {
        connection.write('${jsonEncode(command)}\n');
        await connection.flush();
        var done = false;
        final result = events.moveNext().then((hasEvent) {
          done = true;
          if (!hasEvent) throw StateError('app closed the connection');
          return Map<String, dynamic>.from(jsonDecode(events.current) as Map);
        });
        while (!done) {
          await tester.pump(const Duration(milliseconds: 16));
          await Future<void>.delayed(const Duration(milliseconds: 16));
        }
        return result;
      }

      expect(await send({'command': 'list_screens'}), {
        'event': 'screens',
        'screens': [
          {'name': 'home', 'description': 'Home screen', 'needs_login': false},
          {
            'name': 'details',
            'description': 'Details screen',
            'needs_login': false,
          },
        ],
      });
      expect(await send({'command': 'navigate', 'screen': 'details'}), {
        'event': 'navigated',
        'screen': 'details',
      });
      expect(find.text('Details screen'), findsOneWidget);

      final screenshot = await send({
        'command': 'screenshot',
        'name': 'details',
      });
      final png = base64Decode(screenshot['png'] as String);
      expect(screenshot['event'], 'screenshot');
      final image = await ui.instantiateImageCodec(png);
      final frame = await image.getNextFrame();
      expect(frame.image.width, greaterThan(0));
      expect(frame.image.height, greaterThan(0));
      frame.image.dispose();
      image.dispose();

      expect(await send({'command': 'navigate', 'screen': 'home'}), {
        'event': 'navigated',
        'screen': 'home',
      });
      expect(find.text('Home screen'), findsOneWidget);

      await events.cancel();
      await connection.close();
      await server.close();
    });
  });
}
