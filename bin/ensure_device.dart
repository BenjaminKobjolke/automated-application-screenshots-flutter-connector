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
/// - `DEMO_PACKAGE` — app package to pre-grant screen capture for. Empty:
///   read `applicationId` from the app's Android Gradle file.
///
/// Once a device is ready, this pre-grants `PROJECT_MEDIA` for the app package.
/// If the app is not installed yet, a detached device-side watcher grants it
/// after `flutter run` installs the app.
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

const Duration _bootTimeout = Duration(seconds: 180);

const Duration _pollInterval = Duration(seconds: 2);

const Duration _installWatchTimeout = Duration(minutes: 20);

const Duration _installPollInterval = Duration(seconds: 1);

const _demoPackageEnvironment = 'DEMO_PACKAGE';
const _demoEmulatorEnvironment = 'DEMO_EMULATOR';
const _applicationGradleFiles = [
  'android/app/build.gradle.kts',
  'android/app/build.gradle',
];

Future<int> _main() async {
  if (!await _hasAdb()) {
    stderr.writeln(
      'ensure_device: `adb` not found on PATH. Install the Android platform '
      'tools, or add them to PATH.',
    );
    return 1;
  }
  // Started separately so the daemon's "* daemon started" chatter stays out
  // of the `adb devices` output we parse.
  await _run('adb', ['start-server']);

  final ready = await _readyDevices();
  if (ready.isNotEmpty) {
    stdout.writeln(
      'ensure_device: using ${ready.first.serial}'
      '${ready.length > 1 ? ' (${ready.length} attached)' : ''}',
    );
    final packageName = _resolvePackage();
    if (packageName != null) {
      for (final device in ready) {
        await _grantCapture(packageName, device.serial);
      }
    }
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

  final serial = await _waitForBoot();
  if (serial == null) return 1;
  if (serial.isNotEmpty) {
    final packageName = _resolvePackage();
    if (packageName != null) await _grantCapture(packageName, serial);
  }
  return 0;
}

/// Blocks until a device reports `sys.boot_completed`, or [_bootTimeout] pass.
Future<String?> _waitForBoot() async {
  await _run('adb', ['wait-for-device']);
  final deadline = DateTime.now().add(_bootTimeout);
  while (DateTime.now().isBefore(deadline)) {
    final booted = await _run('adb', [
      'shell',
      'getprop',
      'sys.boot_completed',
    ]);
    if (booted.stdout.toString().trim() == '1') {
      final ready = await _readyDevices();
      final serial = ready.isEmpty ? '' : ready.first.serial;
      stdout.writeln(
        serial.isEmpty
            ? 'ensure_device: device booted'
            : 'ensure_device: $serial booted',
      );
      return serial;
    }
    await Future<void>.delayed(_pollInterval);
  }
  stderr.writeln(
    'ensure_device: emulator did not finish booting within '
    '${_bootTimeout.inSeconds}s.',
  );
  return null;
}

String? _resolvePackage() {
  final configured = Platform.environment[_demoPackageEnvironment]?.trim();
  final packageName = configured != null && configured.isNotEmpty
      ? configured
      : _readApplicationId();
  if (packageName == null) {
    stdout.writeln(
      'ensure_device: no applicationId found (set DEMO_PACKAGE); '
      'video demos will ask for screen-capture consent.',
    );
    return null;
  }
  if (!isAndroidPackageName(packageName)) {
    stdout.writeln(
      'ensure_device: "$packageName" is not a valid package name; '
      'skipping the screen-capture grant.',
    );
    return null;
  }
  return packageName;
}

String? _readApplicationId() {
  for (final path in _applicationGradleFiles) {
    try {
      final file = File(path);
      if (file.existsSync()) {
        final packageName = parseApplicationId(file.readAsStringSync());
        if (packageName != null) return packageName;
      }
    } on FileSystemException {
      // A missing or unreadable Gradle file is equivalent to no declaration.
    }
  }
  return null;
}

Future<void> _grantCapture(String packageName, String serial) async {
  final package = await _run('adb', [
    '-s',
    serial,
    'shell',
    'pm',
    'path',
    packageName,
  ]);
  if (!isPackageInstalled(package.stdout.toString())) {
    try {
      // Keep the device shell syntax off the Windows host shell.
      await Process.start('adb', [
        '-s',
        serial,
        'shell',
        grantWhenInstalledScript(
          packageName,
          attempts:
              _installWatchTimeout.inSeconds ~/ _installPollInterval.inSeconds,
          interval: _installPollInterval,
        ),
      ], mode: ProcessStartMode.detached);
      stdout.writeln(
        'ensure_device: $packageName is not installed on $serial '
        'yet; screen capture will be granted in the background once '
        'flutter run installs it (watching up to '
        '${_installWatchTimeout.inMinutes} min).',
      );
    } on ProcessException catch (error) {
      stdout.writeln(
        'ensure_device: could not start screen-capture watcher '
        'for $packageName on $serial ($error); video demos will ask.',
      );
    }
    return;
  }

  final grant = await _run('adb', [
    '-s',
    serial,
    'shell',
    ...appOpsGrantArgs(packageName),
  ]);
  final output = '${grant.stdout}${grant.stderr}';
  if (appOpsSetSucceeded(grant.exitCode, output)) {
    stdout.writeln(
      'ensure_device: screen capture pre-granted for '
      '$packageName on $serial',
    );
  } else {
    final details = output.trim().isEmpty
        ? 'exit code ${grant.exitCode}'
        : output.trim();
    stdout.writeln(
      'ensure_device: could not pre-grant screen capture for '
      '$packageName on $serial ($details); video demos will ask.',
    );
  }
}

/// Resolves `DEMO_EMULATOR` or Flutter's first AVD; returns null if unavailable.
Future<String?> _resolveAvd() async {
  final configured = Platform.environment[_demoEmulatorEnvironment]?.trim();
  if (configured != null && configured.isNotEmpty) return configured;

  final listed = await _run(_flutter.executable, [
    ..._flutter.leadingArgs,
    'emulators',
  ]);
  final ids = parseEmulatorIds(listed.stdout.toString());
  if (ids.isNotEmpty) return ids.first;

  stderr.writeln(
    'ensure_device: no device attached and no emulator to launch. '
    'Create one, or set DEMO_EMULATOR to an id from `fvm flutter emulators`.',
  );
  return null;
}

/// Devices adb can actually talk to, reporting any that are attached but not.
Future<List<AdbDevice>> _readyDevices() async {
  final listed = await _run('adb', ['devices']);
  final devices = parseAdbDevices(listed.stdout.toString());
  for (final device in devices.where((d) => !d.isReady)) {
    stdout.writeln(
      'ensure_device: ignoring ${device.serial} (${device.state})',
    );
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
