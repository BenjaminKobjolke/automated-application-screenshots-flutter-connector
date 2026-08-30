import 'dart:convert';
import 'dart:typed_data';

import 'package:automated_screenshot_connector/automated_screenshot_connector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('StartCommand parses the tool wire format with defaults', () {
    final cmd = StartCommand.fromJson({'command': 'start', 'demo': 2});
    expect(cmd.demo, 2);
    expect(cmd.video, isFalse);
    expect(cmd.pixelRatio, 1.0);
    expect(cmd.settings, isEmpty);
    expect(cmd.language, isNull);
    expect(cmd.steps, isNull);
  });

  test('StartCommand parses settings, texts and steps', () {
    final cmd = StartCommand.fromJson({
      'command': 'start',
      'demo': 1,
      'video': true,
      'pixel_ratio': 2,
      'settings': {'api_base_url': 'https://demo', 'n': 3},
      'language': 'de',
      'texts': {'price': 'Preis'},
      'steps': [
        {'type': 'tap', 'key': 'x'}
      ],
    });
    expect(cmd.video, isTrue);
    expect(cmd.pixelRatio, 2.0);
    expect(cmd.settings, {'api_base_url': 'https://demo', 'n': '3'});
    expect(cmd.language, 'de');
    expect(cmd.texts, {'price': 'Preis'});
    expect(cmd.steps!.single, isA<TapStep>());
  });

  test('non-start objects are rejected', () {
    expect(() => StartCommand.fromJson({'command': 'stop', 'demo': 1}),
        throwsA(isA<FormatException>()));
  });

  test('events encode as the tool expects', () {
    expect(DemoEvents.demoStarted(1), {'event': 'demo_started', 'demo': 1});
    expect(DemoEvents.screenshot('home', Uint8List.fromList([1, 2, 3])),
        {'event': 'screenshot', 'name': 'home', 'png': base64Encode([1, 2, 3])});
    expect(DemoEvents.videoHeader(1, 9),
        {'event': 'video', 'demo': 1, 'size': 9});
    expect(DemoEvents.error('boom'), {'event': 'error', 'message': 'boom'});
  });
}
