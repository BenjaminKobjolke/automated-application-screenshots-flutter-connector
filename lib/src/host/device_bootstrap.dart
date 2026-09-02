/// Host-side (PC) device bootstrap for demo recording.
///
/// This library is **not** exported from
/// `automated_screenshot_connector.dart`: it runs on the developer's machine
/// via `bin/ensure_device.dart`, never inside the app. It stays free of any
/// Flutter import so the script runs under a plain `dart run`.
///
/// Parsing lives here, apart from process execution, so it can be tested
/// without an emulator or an Android SDK.
library;

import 'dart:convert';

/// Serial of an attached device, and whether it is ready to be used.
class AdbDevice {
  /// Creates a device entry from one `adb devices` row.
  const AdbDevice(this.serial, this.state);

  /// The adb serial, e.g. `emulator-5554`.
  final String serial;

  /// The adb state word, e.g. `device`, `offline`, `unauthorized`.
  final String state;

  /// Whether adb can actually talk to this device.
  bool get isReady => state == 'device';
}

/// Parses `adb devices` output into its device rows.
///
/// Skips the `List of devices attached` header and blank lines. Rows in any
/// state are returned; use [AdbDevice.isReady] to filter, so a caller can tell
/// "nothing attached" from "attached but unauthorized".
List<AdbDevice> parseAdbDevices(String stdout) {
  final devices = <AdbDevice>[];
  for (final line in const LineSplitter().convert(stdout)) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('List of devices')) continue;
    // adb separates serial and state with a tab, but daemon notices ("* daemon
    // started successfully") arrive on the same stream and have neither.
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length < 2 || trimmed.startsWith('*')) continue;
    devices.add(AdbDevice(parts[0], parts[1]));
  }
  return devices;
}

/// Parses `flutter emulators` output into the emulator ids it lists.
///
/// The table rows are `id • name • manufacturer • platform`; everything before
/// the header, the header itself and the trailing help text carry no bullet, so
/// the bullet is what identifies a row.
List<String> parseEmulatorIds(String stdout) {
  final ids = <String>[];
  for (final line in const LineSplitter().convert(stdout)) {
    final trimmed = line.trim();
    if (!trimmed.contains('•')) continue;
    final id = trimmed.split('•').first.trim();
    // The header row ("Id • Name • Manufacturer • Platform") looks like a row.
    if (id.isEmpty || id == 'Id') continue;
    ids.add(id);
  }
  return ids;
}
