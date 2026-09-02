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
    expect(devices.map((d) => d.serial),
        ['emulator-5554', '1a2b3c4d', 'R58M20ABCDE']);
    expect(devices.where((d) => d.isReady).map((d) => d.serial),
        ['R58M20ABCDE']);
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
}
