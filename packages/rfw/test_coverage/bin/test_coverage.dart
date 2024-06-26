// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:lcov_parser/lcov_parser.dart' as lcov;

// Please update these targets when you update this package.
// Please ensure that test coverage continues to be 100%.
const int targetLines = 2127;
const String targetPercent = '100';
const String lastUpdate = '2021-08-30';

Future<void> main(List<String> arguments) async {
  // This script is mentioned in the README.md file.

  if (Platform.environment['CHANNEL'] == 'stable') {
    // For now these are disabled because this package has never been supported
    // on the stable channel and requires newer language features that have not
    // yet shipped to a stable build. It will be possible to test this with the
    // first stable to ship after October 2021.
    print(
      'Skipping tests on stable channel.\n'
      'These tests can be unskipped once we ship a stable after October 2021.',
    );
    exit(0);
  }

  final Directory coverageDirectory = Directory('coverage');

  if (coverageDirectory.existsSync()) {
    coverageDirectory.deleteSync(recursive: true);
  }

  // We run with --update-goldens because the goal here is not to verify the tests
  // pass but to verify the coverage, and the goldens are not always going to pass
  // when run on different platforms (e.g. on Cirrus we run this on a mac but the
  // goldens expect a linux box).
  final ProcessResult result = Process.runSync(
    'flutter',
    <String>['test', '--coverage', '--update-goldens'],
  );
  if (result.exitCode != 0) {
    print(result.stdout);
    print(result.stderr);
    print('Tests failed.');
    exit(1);
  }

  final List<lcov.Record> records = await lcov.Parser.parse(
    'coverage/lcov.info',
  );
  int totalLines = 0;
  int coveredLines = 0;
  for (final lcov.Record record in records) {
    totalLines += record.lines?.found ?? 0;
    coveredLines += record.lines?.hit ?? 0;
  }
  if (totalLines == 0 || totalLines < coveredLines) {
    print('Failed to compute coverage.');
    exit(1);
  }

  final String coveredPercent =
      (100.0 * coveredLines / totalLines).toStringAsFixed(1);

  // We only check the TARGET_LINES matches, not the TARGET_PERCENT,
  // because we expect the percentage to drop over time as Dart fixes
  // various bugs in how it determines what lines are coverable.
  if (coveredLines < targetLines) {
    print('');
    print('                  ╭──────────────────────────────╮');
    print('                  │ COVERAGE REGRESSION DETECTED │');
    print('                  ╰──────────────────────────────╯');
    print('');
    print(
      'Coverage has reduced to only $coveredLines lines ($coveredPercent%). This is lower than',
    );
    print(
      'it was as of $lastUpdate, when coverage was $targetPercent%, covering $targetLines lines.',
    );
    print(
      'Please add sufficient tests to get coverage back to 100%, and update',
    );
    print(
      'test_coverage/bin/test_coverage.dart to have the appropriate targets.',
    );
    print('');
    print(
      'When in doubt, ask @Hixie for advice. Thanks!',
    );
    exit(1);
  } else {
    if (coveredLines < totalLines) {
      print(
        'Warning: Coverage of package:rfw is no longer 100%. (Coverage is now $coveredPercent%.)',
      );
    }
    if (coveredLines > targetLines) {
      print(
        'test_coverage/bin/test_coverage.dart should be updated to have a new target ($coveredLines).',
      );
    }
  }

  coverageDirectory.deleteSync(recursive: true);
}
