/// Shared socket helpers for the connector's tests.
///
/// Every socket test drives a real loopback `ServerSocket` — the package has no
/// socket fakes — so the bind and free-port idioms live here instead of being
/// re-typed per test.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:automated_screenshot_connector/automated_screenshot_connector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

/// Silences connector logging for every test in the calling `main()`.
void silenceLogger() => setUp(() => AppLogger.enabled = false);

/// Binds a server on loopback: a free port by default, or [port] to reclaim
/// one a previous bind released (see [deadPort]).
Future<ServerSocket> bindLoopback([int port = 0]) =>
    ServerSocket.bind(InternetAddress.loopbackIPv4, port);

/// A loopback port guaranteed to refuse connections, by binding then closing.
///
/// The port stays free afterwards, so a test may bind it again to make a
/// connection start failing and then succeed.
Future<int> deadPort() async {
  final server = await bindLoopback();
  final port = server.port;
  await server.close();
  return port;
}

/// Address every socket test connects to.
const String loopbackHost = '127.0.0.1';

final Expando<StreamIterator<String>> _eventLines =
    Expando<StreamIterator<String>>('demo server event lines');

/// Reads the next JSON event line from [connection] before [timeout].
Future<Map<String, dynamic>> nextEvent(
  Socket connection, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final lines = _eventLines[connection] ??= StreamIterator<String>(
    connection
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter()),
  );
  if (!await lines.moveNext().timeout(timeout)) {
    throw StateError('connection closed before the next event');
  }
  return Map<String, dynamic>.from(jsonDecode(lines.current) as Map);
}

/// Sends a live command and pumps frames until its event arrives.
Future<Map<String, dynamic>> sendAndRead(
  WidgetTester tester,
  Socket connection,
  Map<String, Object?> command,
) async {
  connection.write('${jsonEncode(command)}\n');
  await connection.flush();
  final pending = nextEvent(connection);
  var complete = false;
  pending.whenComplete(() => complete = true);
  while (!complete) {
    await tester.pump(const Duration(milliseconds: 16));
    await Future<void>.delayed(const Duration(milliseconds: 16));
  }
  return pending;
}

/// For a tool that turns up shortly after the app starts waiting. Keep the
/// attempt timeout below 500 ms: Windows re-sends a refused loopback SYN
/// after about 500 ms, so an attempt timing out then may still reach the server
/// as an unused connection.
const ConnectRetry fastRetry = ConnectRetry(
  interval: Duration(milliseconds: 20),
  timeout: Duration(seconds: 5),
  attemptTimeout: Duration(milliseconds: 200),
);

/// Gives up almost at once, for asserting the deadline is honoured.
const ConnectRetry expiringRetry = ConnectRetry(
  interval: Duration(milliseconds: 20),
  timeout: Duration(milliseconds: 100),
  attemptTimeout: Duration(milliseconds: 200),
);

/// Outlasts any test, so only cancellation or disposal can end the wait.
const ConnectRetry patientRetry = ConnectRetry(
  interval: Duration(milliseconds: 20),
  timeout: Duration(minutes: 3),
  attemptTimeout: Duration(milliseconds: 200),
);

/// Counts the connections reaching [server] during [window].
///
/// Connections made before the listen starts are held in the OS backlog and
/// still counted, so callers may bind well before they call this.
Future<int> connectionsWithin(ServerSocket server, Duration window) async {
  var connections = 0;
  final sub = server.listen((_) => connections++);
  await Future<void>.delayed(window);
  await sub.cancel();
  return connections;
}
