import 'dart:io';

import 'package:automated_screenshot_connector/automated_screenshot_connector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/demo_server.dart';

void main() {
  silenceLogger();

  group('LiveGesture parsing', () {
    test('parses tap, drag and pinch with duration defaults', () {
      final tap = LiveGesture.fromJson({
        'kind': 'tap',
        'at': [0.2, 0.7],
      });
      final drag = LiveGesture.fromJson({
        'kind': 'drag',
        'from': [0.2, 0.7],
        'to': [0.8, 0.3],
      });
      final pinch = LiveGesture.fromJson({
        'kind': 'pinch',
        'center': [0.5, 0.5],
        'scale': 2,
      });

      expect(tap.kind, GestureKind.tap);
      expect(tap.duration, const Duration(milliseconds: 100));
      expect(drag.kind, GestureKind.drag);
      expect(drag.duration, const Duration(milliseconds: 300));
      expect(pinch.kind, GestureKind.pinch);
      expect(pinch.duration, const Duration(milliseconds: 300));
    });

    test('parses explicit duration and section target', () {
      final gesture = LiveGesture.fromJson({
        'kind': 'tap',
        'at': [0.5, 0.5],
        'duration_ms': 250,
        'screen': 'image_viewer',
        'section': 'image',
      });

      expect(gesture.duration, const Duration(milliseconds: 250));
      expect(gesture.screen, 'image_viewer');
      expect(gesture.section, 'image');
    });

    test('rejects unknown or missing kinds', () {
      for (final json in [
        <String, Object?>{'kind': 'swipe'},
        <String, Object?>{},
      ]) {
        expect(
          () => LiveGesture.fromJson(json),
          throwsA(isA<FormatException>()),
        );
      }
    });

    test('rejects invalid durations, points, scale and section target', () {
      final invalid = <Map<String, Object?>>[
        {
          'kind': 'tap',
          'at': [0.5, 0.5],
          'duration_ms': 0,
        },
        {
          'kind': 'tap',
          'at': [0.5, 0.5],
          'duration_ms': -1,
        },
        {
          'kind': 'tap',
          'at': [1.1, 0.5],
        },
        {
          'kind': 'tap',
          'at': [-0.1, 0.5],
        },
        {
          'kind': 'tap',
          'at': [0.5],
        },
        {'kind': 'tap', 'at': 'middle'},
        {
          'kind': 'drag',
          'from': [0.5, 0.5],
          'to': [0.5, 1.01],
        },
        {
          'kind': 'pinch',
          'center': [0.5, 0.5],
          'scale': 0,
        },
        {
          'kind': 'pinch',
          'center': [0.5, 0.5],
          'scale': -2,
        },
        {
          'kind': 'tap',
          'at': [0.5, 0.5],
          'section': 'image',
        },
      ];

      for (final json in invalid) {
        expect(
          () => LiveGesture.fromJson(json),
          throwsA(isA<FormatException>()),
          reason: '$json',
        );
      }
    });
  });

  testWidgets('pinches and drags an InteractiveViewer and taps a button', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final server = await bindLoopback();
      final accepted = server.first;
      final controller = TransformationController();
      var presses = 0;
      await tester.pumpWidget(
        AutomationDemoHost(
          host: '$loopbackHost:${server.port}',
          registry: DemoRegistry(),
          screens: LiveScreenRegistry(),
          exitWhenDone: false,
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  ElevatedButton(
                    onPressed: () => presses++,
                    child: const Text('Tap me'),
                  ),
                  Expanded(
                    child: InteractiveViewer(
                      transformationController: controller,
                      minScale: 0.1,
                      maxScale: 5,
                      boundaryMargin: const EdgeInsets.all(1000),
                      child: const SizedBox(
                        width: 1000,
                        height: 1000,
                        child: ColoredBox(color: Colors.blue),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final connection = await accepted;

      final buttonRect = tester.getRect(find.text('Tap me'));
      final viewSize = tester.view.physicalSize / tester.view.devicePixelRatio;
      final tapPoint = [
        buttonRect.center.dx / viewSize.width,
        buttonRect.center.dy / viewSize.height,
      ];
      expect(
        await sendAndRead(tester, connection, {
          'command': 'gesture',
          'kind': 'tap',
          'at': tapPoint,
        }),
        {'event': 'gestured', 'kind': 'tap'},
      );
      expect(presses, 1);

      final malformed = await sendAndRead(tester, connection, {
        'command': 'gesture',
        'kind': 'swipe',
      });
      expect(malformed['event'], 'error');
      expect(malformed['message'], contains('malformed tool command'));

      expect(
        await sendAndRead(tester, connection, {
          'command': 'gesture',
          'kind': 'pinch',
          'center': [0.5, 0.6],
          'scale': 2,
          'duration_ms': 100,
        }),
        {'event': 'gestured', 'kind': 'pinch'},
      );
      final zoomedScale = controller.value.getMaxScaleOnAxis();
      expect(zoomedScale, greaterThan(1.5));

      expect(
        await sendAndRead(tester, connection, {
          'command': 'gesture',
          'kind': 'pinch',
          'center': [0.5, 0.6],
          'scale': 0.5,
          'duration_ms': 100,
        }),
        {'event': 'gestured', 'kind': 'pinch'},
      );
      final zoomedOutScale = controller.value.getMaxScaleOnAxis();
      expect(zoomedOutScale, lessThan(zoomedScale));

      final beforeDrag = controller.value.getTranslation().y;
      expect(
        await sendAndRead(tester, connection, {
          'command': 'gesture',
          'kind': 'drag',
          'from': [0.5, 0.8],
          'to': [0.5, 0.4],
          'duration_ms': 100,
        }),
        {'event': 'gestured', 'kind': 'drag'},
      );
      expect(controller.value.getTranslation().y, lessThan(beforeDrag));

      await connection.close();
      await server.close();
      controller.dispose();
    });
  });

  testWidgets('section gesture targets its widget and errors preserve link', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final server = await bindLoopback();
      final accepted = server.first;
      final sectionKey = GlobalKey();
      var presses = 0;
      await tester.pumpWidget(
        AutomationDemoHost(
          host: '$loopbackHost:${server.port}',
          registry: DemoRegistry(),
          screens: LiveScreenRegistry()
            ..add([
              LiveScreen(
                name: 'image_viewer',
                description: 'Image viewer',
                needsLogin: false,
                sections: {'image': sectionKey},
                open: () async {},
              ),
            ]),
          exitWhenDone: false,
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  key: sectionKey,
                  width: 160,
                  height: 100,
                  child: ElevatedButton(
                    onPressed: () => presses++,
                    child: const Text('Section button'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final connection = await accepted;

      expect(
        await sendAndRead(tester, connection, {
          'command': 'gesture',
          'kind': 'tap',
          'at': [0.5, 0.5],
          'screen': 'image_viewer',
          'section': 'image',
        }),
        {'event': 'gestured', 'kind': 'tap'},
      );
      expect(presses, 1);

      final malformed = await sendAndRead(tester, connection, {
        'command': 'gesture',
        'kind': 'swipe',
      });
      expect(malformed['event'], 'error');
      expect(malformed['message'], contains('malformed tool command'));

      final error = await sendAndRead(tester, connection, {
        'command': 'gesture',
        'kind': 'tap',
        'at': [0.5, 0.5],
        'screen': 'image_viewer',
        'section': 'missing',
      });
      expect(error['event'], 'error');
      expect(error['message'], contains('unknown section'));
      expect(
        await sendAndRead(tester, connection, {'command': 'list_screens'}),
        {
          'event': 'screens',
          'screens': [
            {
              'name': 'image_viewer',
              'description': 'Image viewer',
              'needs_login': false,
              'sections': ['image'],
            },
          ],
        },
      );

      await connection.close();
      await server.close();
    });
  });
}
