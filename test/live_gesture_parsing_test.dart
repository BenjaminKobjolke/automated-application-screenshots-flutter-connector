import 'package:automated_screenshot_connector/automated_screenshot_connector.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/demo_server.dart';

void main() {
  silenceLogger();

  group('LiveGesture parsing', () {
    test('parses tap, drag and pinch with duration defaults', () {
      final tap = LiveGesture.fromJson({
        'kind': 'tap',
        'at': [0.2, 0.7],
      });
      final drag = LiveGesture.fromJson({
        'kind': 'drag',
        'from': [0.2, 0.7],
        'to': [0.8, 0.3],
      });
      final pinch = LiveGesture.fromJson({
        'kind': 'pinch',
        'center': [0.5, 0.5],
        'scale': 2,
      });

      expect(tap.kind, GestureKind.tap);
      expect(tap.duration, const Duration(milliseconds: 100));
      expect(drag.kind, GestureKind.drag);
      expect(drag.duration, const Duration(milliseconds: 300));
      expect(pinch.kind, GestureKind.pinch);
      expect(pinch.duration, const Duration(milliseconds: 300));
    });

    test('parses explicit duration and section target', () {
      final gesture = LiveGesture.fromJson({
        'kind': 'tap',
        'at': [0.5, 0.5],
        'duration_ms': 250,
        'screen': 'image_viewer',
        'section': 'image',
      });

      expect(gesture.duration, const Duration(milliseconds: 250));
      expect(gesture.screen, 'image_viewer');
      expect(gesture.section, 'image');
    });

    test('rejects unknown or missing kinds', () {
      for (final json in [
        <String, Object?>{'kind': 'swipe'},
        <String, Object?>{},
      ]) {
        expect(
          () => LiveGesture.fromJson(json),
          throwsA(isA<FormatException>()),
        );
      }
    });

    test('rejects invalid durations, points, scale and section target', () {
      final invalid = <Map<String, Object?>>[
        {
          'kind': 'tap',
          'at': [0.5, 0.5],
          'duration_ms': 0,
        },
        {
          'kind': 'tap',
          'at': [0.5, 0.5],
          'duration_ms': -1,
        },
        {
          'kind': 'tap',
          'at': [1.1, 0.5],
        },
        {
          'kind': 'tap',
          'at': [-0.1, 0.5],
        },
        {
          'kind': 'tap',
          'at': [0.5],
        },
        {'kind': 'tap', 'at': 'middle'},
        {
          'kind': 'drag',
          'from': [0.5, 0.5],
          'to': [0.5, 1.01],
        },
        {
          'kind': 'pinch',
          'center': [0.5, 0.5],
          'scale': 0,
        },
        {
          'kind': 'pinch',
          'center': [0.5, 0.5],
          'scale': -2,
        },
        {
          'kind': 'tap',
          'at': [0.5, 0.5],
          'section': 'image',
        },
      ];

      for (final json in invalid) {
        expect(
          () => LiveGesture.fromJson(json),
          throwsA(isA<FormatException>()),
          reason: '$json',
        );
      }
    });
  });
}
