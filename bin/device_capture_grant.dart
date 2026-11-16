/// Pre-grants Android screen-capture consent for demo recording.
library;

import 'dart:io';

import 'src/host/device_bootstrap.dart';

const Duration _installWatchTimeout = Duration(minutes: 20);
const Duration _installPollInterval = Duration(seconds: 1);

/// Grants screen-capture consent on [serial], waiting briefly for installation.
Future<void> grantCaptureForDevice(
  String packageName,
  String serial, {
  required Future<ProcessResult> Function(String, List<String>) run,
}) async {
  final package = await run('adb', [
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

  final grant = await run('adb', [
    '-s',
    serial,
    'shell',
    ...appOpsGrantArgs(packageName),
  ]);
  final output = '${grant.stdout}${grant.stderr}';
  if (adbCommandSucceeded(grant.exitCode, output)) {
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
