import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:automated_screenshot_connector/automated_screenshot_connector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('client receives start commands and sends lines plus raw bytes',
      () async {
    AppLogger.enabled = false;
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final accepted = server.first;
    final client = (await DemoClient.connect('127.0.0.1', server.port))!;
    final conn = await accepted;
    final received = <int>[];
    final done = conn.listen(received.addAll).asFuture<void>();

    conn.write('${jsonEncode({'command': 'start', 'demo': 3})}\n');
    conn.write('garbage\n');
    conn.write('${jsonEncode({'command': 'start', 'demo': 4})}\n');
    await conn.flush();
    final commands = client.commands.take(2).toList();
    expect((await commands).map((c) => c.demo), [3, 4]);

    client.sendLine(DemoEvents.demoStarted(3));
    await client.sendBytes(Uint8List.fromList([0, 255, 7]));
    await client.close();
    await done;
    await server.close();

    final text = utf8.decode(received, allowMalformed: true);
    final newline = text.indexOf('\n');
    expect(jsonDecode(text.substring(0, newline)),
        {'event': 'demo_started', 'demo': 3});
    expect(received.sublist(received.length - 3), [0, 255, 7]);
  });

  test('connect returns null when nothing listens', () async {
    AppLogger.enabled = false;
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    await server.close();
    expect(await DemoClient.connect('127.0.0.1', port), isNull);
  });
}
