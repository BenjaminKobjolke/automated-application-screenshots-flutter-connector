import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'app_logger.dart';
import 'protocol.dart';

/// How long, and how often, the app keeps trying to reach the demo tool.
///
/// The tool listens for its `network.accept_timeout` (30 s by default) once
/// started, while `flutter run` can spend minutes building and installing.
/// Retrying for longer than the tool's own window is what makes the two
/// startable in either order.
class ConnectRetry {
  /// Creates the policy; the defaults outlast a `flutter run` build + install.
  const ConnectRetry({
    this.interval = const Duration(seconds: 2),
    this.timeout = const Duration(minutes: 3),
    this.attemptTimeout = const Duration(seconds: 10),
  });

  /// Pause between two connect attempts.
  final Duration interval;

  /// Total time to keep trying before giving up.
  final Duration timeout;

  /// Per-attempt `Socket.connect` timeout.
  ///
  /// Dominates the loop period when a firewall drops the SYN instead of
  /// refusing it: the attempt then runs to this timeout rather than failing
  /// immediately.
  final Duration attemptTimeout;
}

/// Socket link to the recording tool: receives `start` commands, sends events.
///
/// Degrades to a no-op on any socket failure — the demo must never crash the
/// app because the tool went away.
class DemoClient {
  DemoClient._(this._socket);

  Socket? _socket;
  final _commands = StreamController<StartCommand>();

  /// Connects to the tool at [host]:[port]; null if it cannot be reached.
  static Future<DemoClient?> connect(String host, int port) async {
    try {
      return await _open(host, port, const ConnectRetry().attemptTimeout);
    } on Object catch (e) {
      AppLogger.e('could not connect to demo tool at $host:$port', error: e);
      return null;
    }
  }

  /// Connects to the tool at [host]:[port], retrying until [retry] runs out.
  ///
  /// Unlike [connect] this survives a tool that is started *after* the app, so
  /// the two may be launched in either order. Returns null once the deadline
  /// passes or [isCancelled] turns true (the host widget was disposed).
  ///
  /// Individual attempts stay silent — one line before the wait and one if it
  /// is given up on — because a blocked port produces an attempt every few
  /// seconds for minutes.
  static Future<DemoClient?> connectWithRetry(
    String host,
    int port, {
    ConnectRetry retry = const ConnectRetry(),
    bool Function()? isCancelled,
  }) async {
    AppLogger.i('waiting for demo tool at $host:$port');
    final deadline = DateTime.now().add(retry.timeout);
    while (isCancelled?.call() != true) {
      try {
        return await _open(host, port, retry.attemptTimeout);
      } on Object catch (_) {
        // Expected until the tool starts listening.
      }
      if (!DateTime.now().isBefore(deadline)) {
        AppLogger.e('gave up waiting for demo tool at $host:$port');
        return null;
      }
      await Future<void>.delayed(retry.interval);
    }
    return null;
  }

  /// Opens the socket and wraps it, or throws if the tool is not reachable.
  static Future<DemoClient> _open(
      String host, int port, Duration timeout) async {
    final socket = await Socket.connect(host, port, timeout: timeout);
    socket.setOption(SocketOption.tcpNoDelay, true);
    final client = DemoClient._(socket);
    client._listen(socket);
    AppLogger.i('connected to demo tool at $host:$port');
    return client;
  }

  /// The tool's `start` commands, one per demo run.
  Stream<StartCommand> get commands => _commands.stream;

  void _listen(Socket socket) {
    socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      (line) {
        if (line.trim().isEmpty) return;
        try {
          _commands.add(StartCommand.fromJson(
              Map<String, dynamic>.from(jsonDecode(line) as Map)));
        } on Object catch (e) {
          AppLogger.e('ignoring malformed tool command: $line', error: e);
        }
      },
      onError: (Object e) => _disable('tool connection failed', e),
      onDone: () => _disable('tool closed the connection', null),
    );
  }

  /// Sends one JSON event line.
  void sendLine(Map<String, Object> payload) {
    final socket = _socket;
    if (socket == null) return;
    try {
      socket.add(utf8.encode('${jsonEncode(payload)}\n'));
    } on Object catch (e) {
      _disable('event send failed', e);
    }
  }

  /// Sends raw [bytes] (the mp4 after its `video` header) and flushes.
  Future<void> sendBytes(Uint8List bytes) async {
    final socket = _socket;
    if (socket == null) return;
    try {
      socket.add(bytes);
      await socket.flush();
    } on Object catch (e) {
      _disable('video upload failed', e);
    }
  }

  /// Closes the link; further sends are no-ops.
  Future<void> close() async {
    final socket = _socket;
    _socket = null;
    await _commands.close();
    await socket?.close();
  }

  void _disable(String why, Object? error) {
    if (_socket == null) return;
    AppLogger.e('$why; demo client disabled', error: error);
    _socket?.destroy();
    _socket = null;
    if (!_commands.isClosed) _commands.close();
  }
}
