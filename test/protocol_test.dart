import 'dart:convert';
import 'dart:typed_data';

import 'package:automated_screenshot_connector/automated_screenshot_connector.dart';
import 'package:flutter/foundation.dart';
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
        {'type': 'tap', 'key': 'x'},
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
    expect(
      () => StartCommand.fromJson({'command': 'stop', 'demo': 1}),
      throwsA(isA<FormatException>()),
    );
  });

  test('ToolCommand parses live commands and their defaults', () {
    expect(
      ToolCommand.fromJson({'command': 'list_screens'}),
      isA<ListScreensCommand>(),
    );

    final navigate = ToolCommand.fromJson({
      'command': 'navigate',
      'screen': 'settings',
    }) as NavigateCommand;
    expect(navigate.screen, 'settings');
    expect(navigate.settings, isEmpty);
    expect(navigate.language, isNull);
    expect(navigate.theme, isNull);
    expect(navigate.section, isNull);

    final configuredNavigate = ToolCommand.fromJson({
      'command': 'navigate',
      'screen': 'details',
      'settings': {'account': 42},
      'language': 'de',
    }) as NavigateCommand;
    expect(configuredNavigate.settings, {'account': '42'});
    expect(configuredNavigate.language, 'de');

    final themedNavigate = ToolCommand.fromJson({
      'command': 'navigate',
      'screen': 'details',
      'theme': 'dark',
      'section': 'summary',
    }) as NavigateCommand;
    expect(themedNavigate.theme, Brightness.dark);
    expect(themedNavigate.section, 'summary');
    expect(
      (ToolCommand.fromJson({
        'command': 'navigate',
        'screen': 'details',
        'theme': 'light',
      }) as NavigateCommand).theme,
      Brightness.light,
    );
    expect(
      () => ToolCommand.fromJson({
        'command': 'navigate',
        'screen': 'details',
        'theme': 'blue',
      }),
      throwsA(isA<FormatException>()),
    );

    final screenshot = ToolCommand.fromJson({
      'command': 'screenshot',
      'name': 'settings',
    }) as ScreenshotCommand;
    expect(screenshot.name, 'settings');
    expect(screenshot.pixelRatio, 1.0);
    expect(screenshot.full, isFalse);
    expect(
      (ToolCommand.fromJson({
        'command': 'screenshot',
        'name': 'details',
        'full': true,
      }) as ScreenshotCommand).full,
      isTrue,
    );
    expect(
      (ToolCommand.fromJson({
        'command': 'screenshot',
        'name': 'details',
        'pixel_ratio': 2,
      }) as ScreenshotCommand).pixelRatio,
      2.0,
    );

    final reset = ToolCommand.fromJson({'command': 'reset'}) as ResetCommand;
    expect(reset.settings, isEmpty);
    expect(reset.language, isNull);
    final configuredReset = ToolCommand.fromJson({
      'command': 'reset',
      'settings': {'account': 'test'},
      'language': 'fr',
    }) as ResetCommand;
    expect(configuredReset.settings, {'account': 'test'});
    expect(configuredReset.language, 'fr');
  });

  test('navigate and screenshot require their string identifier', () {
    expect(
      () => ToolCommand.fromJson({'command': 'navigate'}),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => ToolCommand.fromJson({'command': 'navigate', 'screen': 3}),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => ToolCommand.fromJson({'command': 'screenshot'}),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => ToolCommand.fromJson({'command': 'screenshot', 'name': 3}),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => ToolCommand.fromJson({'command': 'unknown'}),
      throwsA(isA<FormatException>()),
    );
  });

  test('ToolCommand preserves start parsing', () {
    expect(
      ToolCommand.fromJson({'command': 'start', 'demo': 2}),
      isA<StartCommand>(),
    );
  });

  test('events encode as the tool expects', () {
    expect(DemoEvents.demoStarted(1), {'event': 'demo_started', 'demo': 1});
    expect(DemoEvents.screenshot('home', Uint8List.fromList([1, 2, 3])), {
      'event': 'screenshot',
      'name': 'home',
      'png': base64Encode([1, 2, 3]),
    });
    expect(DemoEvents.videoHeader(1, 9), {
      'event': 'video',
      'demo': 1,
      'size': 9,
    });
    expect(DemoEvents.error('boom'), {'event': 'error', 'message': 'boom'});
    expect(
      DemoEvents.screens([
        {
          'name': 'settings',
          'description': 'Settings page',
          'needs_login': true,
        },
      ]),
      {
        'event': 'screens',
        'screens': [
          {
            'name': 'settings',
            'description': 'Settings page',
            'needs_login': true,
          },
        ],
      },
    );
    expect(DemoEvents.navigated('settings'), {
      'event': 'navigated',
      'screen': 'settings',
    });
    expect(DemoEvents.resetDone(), {'event': 'reset_done'});
  });
}
