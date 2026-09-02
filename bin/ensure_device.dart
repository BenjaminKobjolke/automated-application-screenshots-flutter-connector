/// Makes sure an Android device is attached before a demo run.
///
/// Reuses whatever is already attached; otherwise launches an emulator and
/// waits for it to finish booting. A consuming app calls it as one line:
///
/// ```
/// fvm dart run automated_screenshot_connector:ensure_device
/// ```
///
/// so pub resolves this package's location and no app needs a config key for
/// where the connector is checked out.
///
/// Environment:
/// - `DEMO_EMULATOR` — AVD to launch. Empty: the first `flutter emulators` id.
///
/// Exit code 0 means a booted device is ready.
///
/// Output goes to stdout/stderr rather than through the package's `AppLogger`:
/// this is a console tool whose progress text IS its user interface, and
/// `AppLogger` wraps `dart:developer`, which emits nothing at all from a plain
/// `dart run`. Do not "fix" these back to AppLogger.
library;

import 'dart:io';

import 'package:automated_screenshot_connector/src/host/device_bootstrap.dart';

/// Longest wait for an emulator to report a completed boot.
const Duration _bootTimeout = Duration(seconds: 180);

/// Pause between two `sys.boot_completed` polls.
const Duration _pollInterval = Duration(seconds: 2);

Future<int> _main() async {
  if (!await _hasAdb()) {
    stderr.writeln(
        'ensure_device: `adb` not found on PATH. Install the Android platform '
        'tools, or add them to PATH.');
    return 1;
  }
  // Started separately so the daemon's "* daemon started" chatter stays out
  // of the `adb devices` output we parse.
  await _run('adb', ['start-server']);

  final ready = await _readyDevices();
  if (ready.isNotEmpty) {
    stdout.writeln('ensure_device: using ${ready.first.serial}'
        '${ready.length > 1 ? ' (${ready.length} attached)' : ''}');
    return 0;
  }

  final avd = await _resolveAvd();
  if (avd == null) return 1;

  stdout.writeln('ensure_device: no device attached, launching $avd');
  final launch = await _run(_flutter.executable, [
    ..._flutter.leadingArgs,
    'emulators',
    '--launch',
    avd,
  ]);
  if (launch.exitCode != 0) {
    stderr.writeln('ensure_device: could not launch $avd.');
    stderr.writeln(launch.stderr.toString().trim());
    return 1;
  }

  return _waitForBoot();
}

/// Blocks until a device reports `sys.boot_completed`, or [_bootTimeout] pass.
Future<int> _waitForBoot() async {
  await _run('adb', ['wait-for-device']);
  final deadline = DateTime.now().add(_bootTimeout);
  while (DateTime.now().isBefore(deadline)) {
    final booted = await _run('adb', ['shell', 'getprop', 'sys.boot_completed']);
    if (booted.stdout.toString().trim() == '1') {
      final ready = await _readyDevices();
      final serial = ready.isEmpty ? 'emulator' : ready.first.serial;
      stdout.writeln('ensure_device: $serial booted');
      return 0;
    }
    await Future<void>.delayed(_pollInterval);
  }
  stderr.writeln('ensure_device: emulator did not finish booting within '
      '${_bootTimeout.inSeconds}s.');
  return 1;
}

/// The AVD to launch: `DEMO_EMULATOR`, else the first one Flutter lists.
///
/// Returns null after reporting why nothing could be resolved.
Future<String?> _resolveAvd() async {
  final configured = Platform.environment['DEMO_EMULATOR']?.trim();
  if (configured != null && configured.isNotEmpty) return configured;

  final listed = await _run(
    _flutter.executable,
    [..._flutter.leadingArgs, 'emulators'],
  );
  final ids = parseEmulatorIds(listed.stdout.toString());
  if (ids.isNotEmpty) return ids.first;

  stderr.writeln('ensure_device: no device attached and no emulator to launch. '
      'Create one, or set DEMO_EMULATOR to an id from `fvm flutter emulators`.');
  return null;
}

/// Devices adb can actually talk to, reporting any that are attached but not.
Future<List<AdbDevice>> _readyDevices() async {
  final listed = await _run('adb', ['devices']);
  final devices = parseAdbDevices(listed.stdout.toString());
  for (final device in devices.where((d) => !d.isReady)) {
    stdout.writeln('ensure_device: ignoring ${device.serial} (${device.state})');
  }
  return devices.where((d) => d.isReady).toList();
}

Future<bool> _hasAdb() async {
  try {
    await Process.run('adb', ['version']);
    return true;
  } on ProcessException {
    return false;
  }
}

/// How to invoke Flutter: FVM when available, since these projects are pinned.
class _FlutterCommand {
  const _FlutterCommand(this.executable, this.leadingArgs);

  final String executable;
  final List<String> leadingArgs;
}

/// Resolved once — `_run` needs it in several places.
final _FlutterCommand _flutter = _resolveFlutter();

/// Prefers `fvm flutter`: the PATH `flutter` may be a different SDK than the
/// one the project pins, and would launch against it.
_FlutterCommand _resolveFlutter() {
  try {
    final probe = Process.runSync('fvm', ['--version'], runInShell: true);
    if (probe.exitCode == 0) {
      return const _FlutterCommand('fvm', ['flutter']);
    }
  } on ProcessException {
    // fvm not installed; fall through to the PATH flutter.
  }
  return const _FlutterCommand('flutter', []);
}

/// `runInShell` so Windows resolves the `.bat` shims for `fvm` and `flutter`.
Future<ProcessResult> _run(String executable, List<String> args) =>
    Process.run(executable, args, runInShell: true);

Future<void> main() async {
  exitCode = await _main();
}
