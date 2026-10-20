import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'protocol.dart';

/// Encoders for the events the app reports back to the tool.
class DemoEvents {
  DemoEvents._();

  /// Playing begins.
  static Map<String, Object> demoStarted(int demo) => {
    'event': ProtocolNames.demoStarted,
    'demo': demo,
  };

  /// A still captured in-app, PNG bytes inline.
  static Map<String, Object> screenshot(String name, Uint8List png) => {
    'event': ProtocolNames.screenshot,
    'name': name,
    'png': base64Encode(png),
  };

  /// Playing finished.
  static Map<String, Object> demoEnded(int demo) => {
    'event': ProtocolNames.demoEnded,
    'demo': demo,
  };

  /// Reports the app's registered screens.
  static Map<String, Object> screens(List<Map<String, Object>> screens) => {
    'event': ProtocolNames.screens,
    'screens': screens,
  };

  /// Confirms that [screen] has been opened.
  static Map<String, Object> navigated(String screen) => {
    'event': ProtocolNames.navigated,
    'screen': screen,
  };

  /// Confirms that [theme] has been applied.
  static Map<String, Object> themeSet(Brightness theme) => {
    'event': ProtocolNames.themeSet,
    'theme': theme.name,
  };

  /// Confirms that the app has been reset.
  static Map<String, Object> resetDone() => {'event': ProtocolNames.resetDone};

  /// Header announcing [size] raw mp4 bytes that follow immediately.
  static Map<String, Object> videoHeader(int demo, int size) => {
    'event': ProtocolNames.video,
    'demo': demo,
    'size': size,
  };

  /// Something went wrong; the tool fails this run.
  static Map<String, Object> error(String message) => {
    'event': ProtocolNames.error,
    'message': message,
  };
}
