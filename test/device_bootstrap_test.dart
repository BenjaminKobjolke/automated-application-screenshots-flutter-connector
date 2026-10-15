import 'package:automated_screenshot_connector/src/host/device_bootstrap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseAdbDevices skips the header and keeps the ready device', () {
    final devices = parseAdbDevices(
      'List of devices attached\n'
      'emulator-5554\tdevice\n',
    );
    expect(devices, hasLength(1));
    expect(devices.single.serial, 'emulator-5554');
    expect(devices.single.isReady, isTrue);
  });

  test('parseAdbDevices returns nothing for a header-only list', () {
    expect(parseAdbDevices('List of devices attached\n\n'), isEmpty);
  });

  test('parseAdbDevices reports unusable devices instead of dropping them', () {
    final devices = parseAdbDevices(
      'List of devices attached\n'
      'emulator-5554\toffline\n'
      '1a2b3c4d\tunauthorized\n'
      'R58M20ABCDE\tdevice\n',
    );
    expect(devices.map((d) => d.serial), [
      'emulator-5554',
      '1a2b3c4d',
      'R58M20ABCDE',
    ]);
    expect(devices.where((d) => d.isReady).map((d) => d.serial), [
      'R58M20ABCDE',
    ]);
  });

  test('parseAdbDevices ignores adb daemon notices', () {
    final devices = parseAdbDevices(
      '* daemon not running; starting now at tcp:5037\n'
      '* daemon started successfully\n'
      'List of devices attached\n',
    );
    expect(devices, isEmpty);
  });

  test('parseEmulatorIds reads the ids out of the table', () {
    final ids = parseEmulatorIds(
      '4 available emulators:\n'
      '\n'
      'Id             • Name           • Manufacturer • Platform\n'
      '\n'
      'Pixel_2_API_28 • Pixel 2 API 28 •              • android\n'
      'Pixel_9        • Pixel 9        • Google       • android\n'
      'pixel_9.0      • pixel 9.0      • Google       • android\n'
      '\n'
      "To run an emulator, run 'flutter emulators --launch <emulator id>'.\n",
    );
    expect(ids, ['Pixel_2_API_28', 'Pixel_9', 'pixel_9.0']);
  });

  test('parseEmulatorIds ignores the version banner and empty output', () {
    expect(
      parseEmulatorIds(
        '┌─────────────────────────────────────────┐\n'
        '│ A new version of Flutter is available!  │\n'
        '└─────────────────────────────────────────┘\n'
        'No emulators available.\n',
      ),
      isEmpty,
    );
  });

  group('parseApplicationId', () {
    test('reads Kotlin DSL and Groovy declarations', () {
      expect(
        parseApplicationId('applicationId = "de.xida.blockscreen"'),
        'de.xida.blockscreen',
      );
      expect(
        parseApplicationId('applicationId "com.example.app"'),
        'com.example.app',
      );
      expect(
        parseApplicationId("applicationId 'com.example.app'"),
        'com.example.app',
      );
    });

    test('ignores suffix-only declarations and comments', () {
      expect(parseApplicationId('applicationIdSuffix = ".debug"'), isNull);
      expect(
        parseApplicationId(
          'applicationIdSuffix = ".debug"\napplicationId = "com.example.app"',
        ),
        'com.example.app',
      );
      expect(
        parseApplicationId(
          '// applicationId = "old.id"\napplicationId = "new.id"',
        ),
        'new.id',
      );
    });

    test('returns null when no application id is declared', () {
      expect(parseApplicationId('namespace = "com.example"'), isNull);
    });
  });

  group('isAndroidPackageName', () {
    test('accepts Android package names', () {
      expect(isAndroidPackageName('de.xida.blockscreen'), isTrue);
      expect(isAndroidPackageName('com.example.app_1'), isTrue);
    });

    test('rejects malformed and unsafe values', () {
      for (final value in [
        'app',
        '1com.x',
        'com..x',
        'de.xida;reboot',
        'de.xida blockscreen',
        '',
      ]) {
        expect(isAndroidPackageName(value), isFalse, reason: value);
      }
    });
  });

  group('isPackageInstalled', () {
    test('finds package paths in pm output', () {
      expect(
        isPackageInstalled(
          'package:/data/app/~~x/de.xida.blockscreen-1/base.apk\n',
        ),
        isTrue,
      );
    });

    test('rejects empty and error output', () {
      expect(isPackageInstalled(''), isFalse);
      expect(isPackageInstalled('Error: package not found'), isFalse);
    });
  });

  group('appOpsSetSucceeded', () {
    test('requires a zero exit code and no output', () {
      expect(appOpsSetSucceeded(0, ''), isTrue);
      expect(appOpsSetSucceeded(0, '  \n'), isTrue);
      expect(appOpsSetSucceeded(0, 'Error: No UID for x in user 0\n'), isFalse);
      expect(appOpsSetSucceeded(255, ''), isFalse);
    });
  });

  test('appOpsGrantArgs builds the capture grant arguments', () {
    expect(appOpsGrantArgs('de.x.y'), [
      'appops',
      'set',
      'de.x.y',
      'PROJECT_MEDIA',
      'allow',
    ]);
  });

  group('grantWhenInstalledScript', () {
    test('checks for installation and grants capture with bounded retries', () {
      final script = grantWhenInstalledScript(
        'de.x.y',
        attempts: 1200,
        interval: const Duration(seconds: 1),
      );

      expect(script, contains('pm path de.x.y'));
      expect(script, contains('appops set de.x.y PROJECT_MEDIA allow'));
      expect(script, contains('1200'));
      expect(script, contains('sleep 1'));
    });

    test('rejects an unsafe package name', () {
      expect(
        () => grantWhenInstalledScript(
          'de.x;reboot',
          attempts: 1200,
          interval: const Duration(seconds: 1),
        ),
        throwsArgumentError,
      );
    });
  });
}
