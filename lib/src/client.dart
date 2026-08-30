import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'app_logger.dart';
import 'protocol.dart';

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
      final socket = await Socket.connect(host, port,
          timeout: const Duration(seconds: 10));
      socket.setOption(SocketOption.tcpNoDelay, true);
      final client = DemoClient._(socket);
      client._listen(socket);
      AppLogger.i('connected to demo tool at $host:$port');
      return client;
    } on Object catch (e) {
      AppLogger.e('could not connect to demo tool at $host:$port', error: e);
      return null;
    }
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
