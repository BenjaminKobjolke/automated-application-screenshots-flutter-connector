import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:automated_screenshot_connector/automated_screenshot_connector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/demo_server.dart';

class FakeRecorder implements ScreenRecorder {
  final started = <String>[];
  var stopped = 0;

  @override
  Future<bool> start(String name) async {
    started.add(name);
    return true;
  }

  @override
  Future<Uint8List> stop() async {
    stopped++;
    return Uint8List.fromList([9, 8, 7]);
  }
}

class Counter extends StatefulWidget {
  const Counter({super.key});

  @override
  State<Counter> createState() => _CounterState();
}

class _CounterState extends State<Counter> {
  var count = 0;

  @override
  Widget build(BuildContext context) => Column(children: [
        ElevatedButton(
          key: const ValueKey('btn'),
          onPressed: () => setState(() => count++),
          child: Text('count $count'),
        ),
        const TextField(key: ValueKey('field'), autofocus: true),
      ]);
}

/// Reads JSON lines until the `video` header, then that many raw bytes.
Future<(List<Map<String, dynamic>>, List<int>)> readRun(Socket conn) async {
  final buffer = <int>[];
  final events = <Map<String, dynamic>>[];
  final sub = conn.listen(buffer.addAll);
  var offset = 0;
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    final newline = buffer.indexOf(10, offset);
    if (newline == -1) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      continue;
    }
    final event = jsonDecode(utf8.decode(buffer.sublist(offset, newline)))
        as Map<String, dynamic>;
    events.add(event);
    offset = newline + 1;
    if (event['event'] == 'error') break;
    if (event['event'] == 'video') {
      final size = event['size'] as int;
      while (buffer.length < offset + size) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      await sub.cancel();
      return (events, buffer.sublist(offset, offset + size));
    }
  }
  await sub.cancel();
  return (events, <int>[]);
}

void main() {
  silenceLogger();

  testWidgets('a start command drives prepare, steps, stills and video',
      (tester) async {
    final recorder = FakeRecorder();
    final prepared = <String>[];
    var customCalls = 0;
    final registry = DemoRegistry()
      ..add([
        const DemoScript(id: 1, name: 'overview', steps: [
          TapStep('btn'),
          TypeTextStep('{greeting}', charDelayMs: 1),
          ScreenshotStep('home'),
          CustomStep('reset'),
        ]),
      ])
      ..customActions['reset'] = () async => customCalls++;

    await tester.runAsync(() async {
      final server = await bindLoopback();
      final accepted = server.first;
      await tester.pumpWidget(AutomationDemoHost(
        host: '$loopbackHost:${server.port}',
        registry: registry,
        recorder: recorder,
        onPrepare: (settings, language) async =>
            prepared.add('${settings['api']}/$language'),
        child: const MaterialApp(home: Scaffold(body: Counter())),
      ));
      final conn = await accepted;
      conn.write('${jsonEncode({
            'command': 'start',
            'demo': 1,
            'video': true,
            'settings': {'api': 'demo'},
            'language': 'de',
            'texts': {'greeting': 'hi'},
          })}\n');
      await conn.flush();

      // The executor runs on real timers; keep frames flowing meanwhile.
      var finished = false;
      final run = readRun(conn).whenComplete(() => finished = true);
      while (!finished) {
        await tester.pump(const Duration(milliseconds: 16));
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
      final (events, video) = await run;
      await server.close();

      expect(prepared, ['demo/de']);
      expect(recorder.started, ['demo_1']);
      expect(recorder.stopped, 1);
      expect(customCalls, 1);
      expect(events.map((e) => e['event']).toList(),
          ['demo_started', 'screenshot', 'demo_ended', 'video']);
      expect(events[1]['name'], 'home');
      final png = base64Decode(events[1]['png'] as String);
      expect(png.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
      expect(video, [9, 8, 7]);
    });
    expect(find.text('count 1'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('field')))
            .controller, isNull);
    expect(find.text('hi'), findsOneWidget);
  });

  testWidgets('an unknown demo is reported as an error event', (tester) async {
    await tester.runAsync(() async {
      final server = await bindLoopback();
      final accepted = server.first;
      await tester.pumpWidget(AutomationDemoHost(
        host: '$loopbackHost:${server.port}',
        registry: DemoRegistry(),
        recorder: FakeRecorder(),
        child: const SizedBox(),
      ));
      final conn = await accepted;
      conn.write('${jsonEncode({'command': 'start', 'demo': 9})}\n');
      await conn.flush();
      final (events, _) = await readRun(conn);
      await server.close();
      expect(events.single['event'], 'error');
      expect(events.single['message'], contains('No demo with id 9'));
    });
  });

  testWidgets('the tool disconnecting restores the app state after the demo',
      (tester) async {
    final calls = <String>[];
    final registry = DemoRegistry()
      ..add([const DemoScript(id: 1, name: 'noop', steps: [CustomStep('mark')])])
      ..customActions['mark'] = () async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        calls.add('demo');
      };

    await tester.runAsync(() async {
      final server = await bindLoopback();
      final accepted = server.first;
      await tester.pumpWidget(AutomationDemoHost(
        host: '$loopbackHost:${server.port}',
        registry: registry,
        onPrepare: (settings, language) async => calls.add('prepare'),
        onRestore: () async => calls.add('restore'),
        child: const SizedBox(),
      ));
      final conn = await accepted;
      conn.write('${jsonEncode({'command': 'start', 'demo': 1})}\n');
      await conn.flush();
      // The tool hangs up while the demo is still playing: the run has to
      // finish before the app puts its own state back.
      await conn.close();

      final deadline = DateTime.now().add(const Duration(seconds: 20));
      while (calls.length < 3 && DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 16));
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
      await server.close();

      expect(calls, ['prepare', 'demo', 'restore']);
    });
  });

  testWidgets('without a host the child renders and nothing connects',
      (tester) async {
    await tester.runAsync(() async {
      final server = await bindLoopback();
      await tester.pumpWidget(AutomationDemoHost(
        host: '',
        registry: DemoRegistry(),
        child: const Text('plain', textDirection: TextDirection.ltr),
      ));
      final connections =
          await connectionsWithin(server, const Duration(milliseconds: 200));
      await server.close();

      expect(find.text('plain'), findsOneWidget);
      expect(connections, isZero);
    });
  });

  test('demo mode is off without the dart-define', () {
    // The test binary is built without AUTOMATION_HOST, so apps keep their
    // debug banner (and anything else keyed off this) in normal runs.
    expect(demoModeEnabled, isFalse);
  });

  testWidgets('disposing the host stops the retry loop', (tester) async {
    await tester.runAsync(() async {
      final port = await deadPort();
      await tester.pumpWidget(AutomationDemoHost(
        host: '$loopbackHost:$port',
        registry: DemoRegistry(),
        retry: patientRetry,
        child: const SizedBox(),
      ));
      await tester.pumpWidget(const SizedBox());

      // The tool turns up after the host is gone; nothing may still be waiting.
      final server = await bindLoopback(port);
      final connections =
          await connectionsWithin(server, const Duration(milliseconds: 300));
      await server.close();

      expect(connections, isZero);
    });
  });
}
