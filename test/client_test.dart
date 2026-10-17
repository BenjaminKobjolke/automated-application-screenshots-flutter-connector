import 'dart:convert';
import 'dart:typed_data';

import 'package:automated_screenshot_connector/automated_screenshot_connector.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/demo_server.dart';

void main() {
  silenceLogger();

  test(
    'client receives tool commands and sends lines plus raw bytes',
    () async {
      final server = await bindLoopback();
      final accepted = server.first;
      final client = (await DemoClient.connect(loopbackHost, server.port))!;
      final conn = await accepted;
      final received = <int>[];
      final done = conn.listen(received.addAll).asFuture<void>();

      conn.write('${jsonEncode({'command': 'list_screens'})}\n');
      conn.write('garbage\n');
      conn.write('${jsonEncode({'command': 'start', 'demo': 4})}\n');
      await conn.flush();
      final commands = client.commands.take(2).toList();
      final receivedCommands = await commands;
      expect(receivedCommands.first, isA<ListScreensCommand>());
      expect(receivedCommands.last, isA<StartCommand>());
      expect((receivedCommands.last as StartCommand).demo, 4);

      client.sendLine(DemoEvents.demoStarted(3));
      await client.sendBytes(Uint8List.fromList([0, 255, 7]));
      await client.close();
      await done;
      await server.close();

      final text = utf8.decode(received, allowMalformed: true);
      final newline = text.indexOf('\n');
      expect(jsonDecode(text.substring(0, newline)), {
        'event': 'demo_started',
        'demo': 3,
      });
      expect(received.sublist(received.length - 3), [0, 255, 7]);
    },
  );

  test('connect returns null when nothing listens', () async {
    expect(await DemoClient.connect(loopbackHost, await deadPort()), isNull);
  });

  test('connectWithRetry waits for a tool that starts later', () async {
    final port = await deadPort();
    final pending = DemoClient.connectWithRetry(
      loopbackHost,
      port,
      retry: fastRetry,
    );

    // The tool only starts listening after the first attempts have failed.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final server = await bindLoopback(port);
    // Keep accepting: `server.first` closes the listener after one connection,
    // and that one can be an attempt the client had already given up on.
    final accepting = server.listen(
      (conn) => conn.listen(
        (_) {},
        onError: (Object _) => conn.destroy(),
        onDone: conn.destroy,
      ),
    );

    final client = await pending;
    expect(client, isNotNull);

    // The listener hangs up once the client closes, letting its close future
    // complete without closing the tool side by hand first.
    final sub = client!.commands.listen((_) {});
    await client.close();
    await sub.cancel();
    await accepting.cancel();
    await server.close();
  });

  test('connectWithRetry gives up once its timeout elapses', () async {
    final port = await deadPort();
    final started = DateTime.now();
    final client = await DemoClient.connectWithRetry(
      loopbackHost,
      port,
      retry: expiringRetry,
    );
    expect(client, isNull);
    expect(
      DateTime.now().difference(started),
      lessThan(const Duration(seconds: 5)),
    );
  });

  test('connectWithRetry stops as soon as it is cancelled', () async {
    final port = await deadPort();
    var cancelled = false;
    final pending = DemoClient.connectWithRetry(
      loopbackHost,
      port,
      retry: patientRetry,
      isCancelled: () => cancelled,
    );
    await Future<void>.delayed(const Duration(milliseconds: 60));
    cancelled = true;
    expect(await pending, isNull);
  });
}
