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
import 'package:syncare_flutter/features/auth/session_controller.dart';
import 'package:syncare_flutter/features/patient/approved_plan_providers.dart';
import 'package:syncare_flutter/features/patient/plan_screen.dart';
import 'package:syncare_flutter/models/verified_care_plan.dart';
import 'package:syncare_flutter/models/session.dart';
import '../test/helpers/fakes.dart';
import '../test/helpers/pump_app.dart';

void main() {
  VerifiedPlanPage? captured;
  test(
    'actual M08 verified HTTP/provider plans exclude internal notes and isolate logout/account switch',
    () async {
      final previous = HttpOverrides.current;
      HttpOverrides.global = null;
      addTearDown(() => HttpOverrides.global = previous);
      final accounts =
          (readPrivateFixture(
                File('../SynCare-be/data/local-demo-accounts.json'),
              ))['patients']
              as List;
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
        final current =
            (scope.read(sessionControllerProvider) as SessionAuthenticated)
                .session
                .principal
                .patientId!;
        captured = await scope.read(apiProvider).listVerifiedPlans(current);
        expect(captured!.plans, isNotEmpty);
        expect(
          captured!.plans.every((p) => p.record.patientId == current),
          true,
        );
        expect(
          captured!.plans.every(
            (p) =>
                !p.record.planJsonString.contains('INTERNAL M08') &&
                !p.record.planJsonString.contains('source_input') &&
                p.record.reviewerNote.isEmpty,
          ),
          true,
        );
        final listener = scope.listen(verifiedPlansProvider, (_, _) {});
        addTearDown(listener.close);
        for (
          var i = 0;
          i < 100 && scope.read(verifiedPlansProvider).valueOrNull == null;
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 30));
        }
        expect(
          scope.read(verifiedPlansProvider).valueOrNull!.plans,
          isNotEmpty,
        );
        await session.logout();
        expect(scope.read(verifiedPlansProvider).valueOrNull, isNull);
        await session.login(
          accounts[1]['identifier'] as String,
          accounts[1]['password'] as String,
        );
        await expectLater(
          scope.read(apiProvider).listVerifiedPlans(current),
          throwsA(isA<NotFoundException>()),
        );
        File('../SynCare-be/data/m08-flutter-evidence.json').writeAsStringSync(
          jsonEncode({
            'verifiedAt': DateTime.now().toUtc().toIso8601String(),
            'actualHTTP': true,
            'nativeDevice': false,
            'plans': captured!.plans.length,
            'ids': captured!.plans.map((p) => p.id).toList(),
          }),
        );
      } finally {
        await session.logout();
      }
    },
  );
  testWidgets(
    'actual captured approved projection at320 text200 preserves provenance and disclaimer without staff note',
    (tester) async {
      expect(captured, isNotNull);
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        wrapScreen(
          Scaffold(
            body: VerifiedPlansContent(
              page: captured!,
              onRefresh: () {},
              onNext: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Persetujuan terverifikasi:'), findsOneWidget);
      expect(find.text('Catatan peninjau'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.textContaining(
          'Persetujuan dan audit telah diverifikasi oleh server.',
        ),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
