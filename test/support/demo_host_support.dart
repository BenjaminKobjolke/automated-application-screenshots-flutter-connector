import 'dart:convert';
import 'dart:io';

import 'package:automated_screenshot_connector/automated_screenshot_connector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'demo_server.dart';

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
  Widget build(BuildContext context) => Column(
    children: [
      ElevatedButton(
        key: const ValueKey('btn'),
        onPressed: () => setState(() => count++),
        child: Text('count $count'),
      ),
      const TextField(key: ValueKey('field'), autofocus: true),
    ],
  );
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
    final event = jsonDecode(
      utf8.decode(buffer.sublist(offset, newline)),
    ) as Map<String, dynamic>;
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

/// Pumps the tree and the event loop until [done] or the deadline passes.
///
/// The host's teardown runs on real sockets and real timers, so a test has to
/// keep both the widget binding and the Dart event loop turning while waiting.
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() done, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!done() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 16));
    await Future<void>.delayed(const Duration(milliseconds: 16));
  }
}

/// Records the `flutter/platform` calls the host makes - the app-closing
/// `SystemNavigator.pop` among them.
List<String> capturePlatformCalls(WidgetTester tester) {
  final calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      calls.add(call.method);
      return null;
    },
  );
  return calls;
}

/// Plays one no-op demo, then hangs up the way the tool does at the end of a
/// run, and waits for the host's teardown to settle.
Future<void> playRunAndDisconnect(
  WidgetTester tester, {
  required bool exitWhenDone,
  required bool Function() done,
  Duration timeout = const Duration(seconds: 20),
}) async {
  final server = await bindLoopback();
  final accepted = server.first;
  await tester.pumpWidget(
    AutomationDemoHost(
      host: '$loopbackHost:${server.port}',
      registry: DemoRegistry()
        ..add([const DemoScript(id: 1, name: 'noop', steps: [])]),
      exitWhenDone: exitWhenDone,
      child: const SizedBox(),
    ),
  );
  final conn = await accepted;
  conn.write('${jsonEncode({'command': 'start', 'demo': 1})}\n');
  await conn.flush();
  await conn.close();
  await pumpUntil(tester, done, timeout: timeout);
  await server.close();
}
