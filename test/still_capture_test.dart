import 'dart:async';
import 'dart:typed_data';

import 'package:automated_screenshot_connector/automated_screenshot_connector.dart';
import 'package:automated_screenshot_connector/src/gesture_driver.dart';
import 'package:automated_screenshot_connector/src/live_input_driver.dart';
import 'package:automated_screenshot_connector/src/step_executor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('background capture returns a clear error without rendering', (
    tester,
  ) async {
    final key = GlobalKey();
    await _pumpBoundary(tester, key);
    addTearDown(() => _resumeLifecycle(tester));
    _pauseLifecycle(tester);

    await tester.runAsync(() async {
      await expectLater(
        StillCapture(
          key,
          resumeTimeout: const Duration(milliseconds: 50),
        ).capture(1),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('app is in the background'),
          ),
        ),
      );
    });
  });

  testWidgets('capture waits for resume and then returns PNG bytes', (
    tester,
  ) async {
    final key = GlobalKey();
    await _pumpBoundary(tester, key);
    addTearDown(() => _resumeLifecycle(tester));
    _pauseLifecycle(tester);

    await tester.runAsync(() async {
      final capture = StillCapture(
        key,
        resumeTimeout: const Duration(seconds: 2),
      ).capture(1);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      _resumeLifecycle(tester);

      final png = await capture;
      expect(png, isA<Uint8List>());
      expect(png.sublist(0, 4), [0x89, 0x50, 0x4e, 0x47]);
    });
  });

  testWidgets('resumed capture returns PNG bytes', (tester) async {
    final key = GlobalKey();
    await _pumpBoundary(tester, key);

    await tester.runAsync(() async {
      final png = await StillCapture(key).capture(1);

      expect(png.sublist(0, 4), [0x89, 0x50, 0x4e, 0x47]);
    });
  });

  testWidgets('full capture errors in background before expanding layout', (
    tester,
  ) async {
    final key = GlobalKey();
    await _pumpBoundary(tester, key);
    addTearDown(() => _resumeLifecycle(tester));
    _pauseLifecycle(tester);
    final extraHeight = ValueNotifier<double?>(null);
    addTearDown(extraHeight.dispose);
    final session = LiveSession(
      screens: LiveScreenRegistry(),
      capture: LiveCapture(
        StillCapture(key, resumeTimeout: const Duration(milliseconds: 50)),
        extraHeight,
      ),
      input: LiveInputDriver(
        steps: StepExecutor(
          still: StillCapture(key),
          onStill: (_, __) {},
          actions: const {},
        ),
        reader: const VisibleTextReader(),
        gestures: GestureDriver(),
        devicePixelRatio: 1,
      ),
    );

    final event = await tester.runAsync(
      () => session.handle(const ScreenshotCommand(name: 'full', full: true)),
    );

    expect(event!['event'], 'error');
    expect(event['message'], contains('app is in the background'));
    expect(extraHeight.value, isNull);
  });
}

Future<void> _pumpBoundary(WidgetTester tester, GlobalKey key) async {
  await tester.pumpWidget(
    MaterialApp(
      home: RepaintBoundary(
        key: key,
        child: const Scaffold(body: Text('Ready')),
      ),
    ),
  );
}

void _pauseLifecycle(WidgetTester tester) {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
}

void _resumeLifecycle(WidgetTester tester) {
  if (tester.binding.lifecycleState == AppLifecycleState.resumed) return;
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}
