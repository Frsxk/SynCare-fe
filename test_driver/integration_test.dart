import '../tool/private_fixture.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/common.dart';

Future<void> main() async {
  FlutterDriver? driver;
  var stage = 'connect';
  try {
    driver = await FlutterDriver.connect(
      printCommunication: false,
      logCommunicationToFile: false,
    );
    final file = File('../SynCare-be/data/m10-e2e-private.json');
    final Map<String, dynamic> fixture;
    if (file.existsSync()) {
      final saved = readPrivateFixture(file);
      fixture = {
        'phase': saved['phase'],
        'runId': saved['runId'],
        'patients': (saved['patients'] as List).map((value) {
          final p = value as Map<String, dynamic>;
          return {
            for (final key in [
              'identifier',
              'password',
              'patientId',
              'slot',
              'uiReport',
              'baseline',
            ])
              if (p[key] != null) key: p[key],
          };
        }).toList(),
      };
    } else {
      final accounts = readPrivateFixture(
        File('../SynCare-be/data/local-demo-accounts.json'),
      );
      fixture = {
        'phase': 'smoke',
        'patients': (accounts['patients'] as List).take(2).toList(),
      };
    }
    final phase = fixture['phase'] as String;
    if (!['smoke', 'identity_commit', 'identity_restore'].contains(phase)) {
      throw const FormatException('unsupported_phase');
    }
    stage = 'runtime_fixture';
    final receipt = await driver.requestData(
      'syncare-fixture:${base64Url.encode(utf8.encode(jsonEncode(fixture)))}',
      timeout: const Duration(seconds: 30),
    );
    if (receipt != 'fixture_received') {
      throw const FormatException('runtime_fixture_not_accepted');
    }
    stage = 'real_client_test';
    final response = Response.fromJson(
      await driver.requestData(null, timeout: const Duration(minutes: 15)),
    );
    File(
      '../SynCare-be/data/m10-sdk-$phase-evidence.json',
    ).writeAsStringSync(response.toJson());
    if (!response.allTestsPassed) {
      stderr.writeln(
        'Actual client assertions failed; details retained privately.',
      );
      exitCode = 1;
    } else {
      stdout.writeln(
        'Actual Flutter integration phase passed: $phase. Private values omitted.',
      );
    }
  } catch (error) {
    final detail = error.toString();
    final tags = [
      'Timeout',
      'timed out',
      'Unknown command',
      'not implemented',
      'isError',
      'invalid argument',
      'fixture_received',
      'syncare-fixture:',
      'null',
      'NoSuchMethod',
      'SyntaxError',
    ].where(detail.contains).toList();
    stderr.writeln(
      'Flutter integration driver failed at $stage (${error.runtimeType}); diagnostic tags: $tags; private values omitted.',
    );
    exitCode = 1;
  } finally {
    await driver?.close();
  }
}
