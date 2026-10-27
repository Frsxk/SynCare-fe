import '../tool/private_fixture.dart';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncare_flutter/core/api_exception.dart';
import 'package:syncare_flutter/core/providers.dart';
import 'package:syncare_flutter/core/session_api.dart';
import 'package:syncare_flutter/core/theme.dart';
import 'package:syncare_flutter/features/auth/session_controller.dart';
import 'package:syncare_flutter/features/patient/checkin_providers.dart';
import 'package:syncare_flutter/features/patient/checkin_detail_screen.dart';
import 'package:syncare_flutter/models/checkin_record.dart';
import 'package:syncare_flutter/models/session.dart';
import '../test/helpers/fakes.dart';

void main() {
  CheckinRecord? captured;
  EmergencyGuidance? guidance;
  test(
    'actual Dio and generation-bound M04 controller commit/read/history for linked patient and reject foreign detail',
    () async {
      final previous = HttpOverrides.current;
      HttpOverrides.global = null;
      addTearDown(() => HttpOverrides.global = previous);
      final accounts =
          (readPrivateFixture(
                File('../SynCare-be/data/local-demo-accounts.json'),
              ))['patients']
              as List;
      final evidence =
          jsonDecode(
                File(
                  '../SynCare-be/data/m04-live-evidence.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final dio = Dio(
        BaseOptions(
          baseUrl: 'http://127.0.0.1:8080',
          contentType: Headers.jsonContentType,
          followRedirects: false,
        ),
      );
      final scope = ProviderContainer(
        overrides: [
          sessionApiProvider.overrideWithValue(DioSessionApi(dio)),
          tokenSourceProvider.overrideWithValue(FakeTokenSource()),
          apiBaseUrlProvider.overrideWithValue('http://127.0.0.1:8080'),
        ],
      );
      addTearDown(() {
        scope.dispose();
        dio.close(force: true);
      });
      scope.read(sessionControllerProvider);
      await Future<void>.delayed(Duration.zero);
      final session = scope.read(sessionControllerProvider.notifier);
      try {
        await session.login(
          accounts[0]['identifier'] as String,
          accounts[0]['password'] as String,
        );
        final own =
            (scope.read(sessionControllerProvider) as SessionAuthenticated)
                .session
                .principal
                .patientId!;
        final controller = scope.read(checkinSubmitProvider.notifier);
        await controller.submit(
          'DATA SINTETIS DARI FLUTTER INTEGRATION TEST. Hari ini merasa baik dan tidak ada keluhan. Obat diminum teratur.',
        );
        expect(scope.read(checkinSubmitProvider), isA<CheckinSaved>());
        for (var i = 0; i < 100; i++) {
          final saved = scope.read(checkinSubmitProvider) as CheckinSaved;
          if (!saved.record.processing.isPending) {
            captured = saved.record;
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 600));
          await controller.refresh();
        }
        expect(captured?.processing, ProcessingState.succeeded);
        expect(captured!.patientId, own);
        expect(captured!.outcome, isA<RoutineCheckinOutcome>());
        final page = await scope.read(apiProvider).listCheckins(own);
        expect(page.records.any((r) => r.id == captured!.id), isTrue);
        guidance = await scope.read(apiProvider).getEmergencyGuidance();
        expect(guidance!.contacts.any((c) => c.number == '119'), isTrue);
        final foreign =
            (evidence['reports'] as List).firstWhere(
                  (r) => r['patientId'] != own,
                )['id']
                as String;
        await expectLater(
          scope.read(apiProvider).getCheckin(foreign),
          throwsA(isA<NotFoundException>()),
        );
        await session.logout();
        await session.login(
          accounts[1]['identifier'] as String,
          accounts[1]['password'] as String,
        );
        expect(scope.read(checkinSubmitProvider), isA<CheckinDraft>());
        await expectLater(
          scope.read(apiProvider).getCheckin(captured!.id),
          throwsA(isA<NotFoundException>()),
        );
      } finally {
        await session.logout();
      }
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );
  testWidgets(
    'exact captured committed F2 report renders in patient detail evidence without network or score recomputation',
    (tester) async {
      expect(captured, isNotNull);
      expect(guidance, isNotNull);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            emergencyGuidanceProvider.overrideWith((_) async => guidance!),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: CheckinEvidence(record: captured!),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Laporan tersimpan'), findsOneWidget);
      expect(find.text('ID laporan: ${captured!.id}'), findsOneWidget);
      expect(find.text('Analisis selesai.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
