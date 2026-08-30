import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_screen_recording/flutter_screen_recording.dart';

/// Records the device screen to one mp4 per demo.
///
/// An interface so tests (and apps with their own recorder) can swap the
/// plugin out; [PluginScreenRecorder] is the production implementation.
abstract interface class ScreenRecorder {
  /// Starts recording; false if the user declined or recording is unavailable.
  Future<bool> start(String name);

  /// Stops recording and returns the mp4 bytes.
  Future<Uint8List> stop();
}

/// [ScreenRecorder] over the `flutter_screen_recording` plugin
/// (MediaProjection on Android, ReplayKit on iOS).
class PluginScreenRecorder implements ScreenRecorder {
  /// Creates the plugin-backed recorder.
  const PluginScreenRecorder();

  @override
  Future<bool> start(String name) => FlutterScreenRecording.startRecordScreen(
        name,
        titleNotification: 'Demo recording',
        messageNotification: 'Recording $name',
      );

  @override
  Future<Uint8List> stop() async {
    final path = await FlutterScreenRecording.stopRecordScreen;
    if (path.isEmpty) throw StateError('screen recording produced no file');
    final file = File(path);
    try {
      return await file.readAsBytes();
    } finally {
      // The tool keeps the copy; the phone does not need to fill up.
      await file.delete().catchError((_) => file);
    }
  }
}
