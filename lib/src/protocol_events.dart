import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'live_gesture.dart';
import 'live_input.dart';
import 'protocol.dart';
import 'visible_text.dart';

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

  /// Confirms that [kind] has finished on the current screen.
  static Map<String, Object> gestured(GestureKind kind) => {
    'event': ProtocolNames.gestured,
    'kind': kind.wireName,
  };

  /// Reports [entries] read from the current screen.
  static Map<String, Object> visibleText(List<VisibleTextEntry> entries) => {
    'event': ProtocolNames.visibleText,
    'entries': entries.map((entry) => entry.toJson()).toList(),
  };

  /// Confirms a tap selected by [text].
  static Map<String, Object> textTapped(String text) => {
    'event': ProtocolNames.textTapped,
    'text': text,
  };

  /// Confirms a tap selected by [key].
  static Map<String, Object> keyTapped(String key) => {
    'event': ProtocolNames.keyTapped,
    'key': key,
  };

  /// Confirms that [text] was typed into the app.
  static Map<String, Object> textTyped(String text) => {
    'event': ProtocolNames.textTyped,
    'text': text,
  };

  /// Confirms that [key] was pressed inside the app.
  static Map<String, Object> keyPressed(LiveKey key) => {
    'event': ProtocolNames.keyPressed,
    'key': key.wireName,
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
