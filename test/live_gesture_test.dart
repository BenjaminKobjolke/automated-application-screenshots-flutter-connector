import 'package:automated_screenshot_connector/automated_screenshot_connector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/demo_server.dart';

void main() {
  silenceLogger();

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
