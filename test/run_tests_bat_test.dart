import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('test runner streams expanded output and preserves its exit code', () {
    final lines = File('tools/run_tests.bat').readAsLinesSync();
    final runnerLines = lines
        .where((line) => line.trim().startsWith('fvm flutter test'))
        .toList();

    expect(runnerLines, hasLength(1));
    expect(runnerLines.single, contains('--reporter expanded'));
    expect(runnerLines.single, isNot(contains('>')));
    expect(runnerLines.single, isNot(contains('|')));

    final runnerIndex = lines.indexWhere(
      (line) => line.trim().startsWith('fvm flutter test'),
    );
    final nextNonEmptyLine = lines
        .skip(runnerIndex + 1)
        .firstWhere((line) => line.trim().isNotEmpty)
        .trim();
    final lastNonEmptyLine = lines
        .lastWhere((line) => line.trim().isNotEmpty)
        .trim();

    expect(nextNonEmptyLine, 'set TESTRESULT=%ERRORLEVEL%');
    expect(lastNonEmptyLine, 'exit /b %TESTRESULT%');
    expect(lines.join('\n'), isNot(contains('TESTLOG')));
  });
}
