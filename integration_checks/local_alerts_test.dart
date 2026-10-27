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
import 'package:syncare_flutter/features/patient/alert_providers.dart';
import 'package:syncare_flutter/features/patient/alert_detail_screen.dart';
import 'package:syncare_flutter/features/patient/checkin_providers.dart';
import 'package:syncare_flutter/models/escalation.dart';
import 'package:syncare_flutter/models/checkin_record.dart';
import 'package:syncare_flutter/models/session.dart';
import '../test/helpers/fakes.dart';
import '../test/helpers/pump_app.dart';

void main() {
  Escalation? captured;
  EmergencyGuidance? guidance;
  test(
    'actual M07 own HTTP/provider status/history/public summaries, logout/account isolation and foreign404',
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
                  '../SynCare-be/data/m07-source-evidence.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final browserEvidence =
          jsonDecode(
                File(
                  '../SynCare-be/data/m07-browser-evidence.json',
                ).readAsStringSync(),
              )
              as List;
      final id = browserEvidence.isEmpty
          ? evidence['ownAlertId'] as String
          : browserEvidence.last['id'] as String;
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
                .session;
        final api = scope.read(apiProvider),
            page = await api.listEscalations(current.principal.patientId!);
        expect(page.alerts.any((a) => a.id == id), true);
        captured = await api.getEscalation(id);
        guidance = await api.getEmergencyGuidance();
        expect(captured!.status, EscalationStatus.resolved);
        expect(captured!.timeline.length, 4);
        expect(
          captured!.timeline.any(
            (e) => e.patientSummary?.contains('simulasi') ?? false,
          ),
          true,
        );
        final subscription = scope.listen(alertDetailProvider(id), (_, _) {});
        addTearDown(subscription.close);
        for (
          var i = 0;
          i < 100 && scope.read(alertDetailProvider(id)).valueOrNull == null;
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 30));
        }
        expect(scope.read(alertDetailProvider(id)).valueOrNull?.id, id);
        await session.logout();
        expect(scope.read(alertDetailProvider(id)).valueOrNull, isNull);
        await session.login(
          accounts[1]['identifier'] as String,
          accounts[1]['password'] as String,
        );
        await expectLater(
          scope.read(apiProvider).getEscalation(id),
          throwsA(isA<NotFoundException>()),
        );
        expect(scope.read(alertDetailProvider(id)).valueOrNull, isNull);
        File('../SynCare-be/data/m07-flutter-evidence.json').writeAsStringSync(
          jsonEncode({
            'verifiedAt': DateTime.now().toUtc().toIso8601String(),
            'id': id,
            'status': captured!.status.name,
            'version': captured!.version,
            'timeline': captured!.timeline.length,
            'actualHTTP': true,
            'nativeDevice': false,
          }),
        );
      } finally {
        await session.logout();
      }
    },
  );
  testWidgets(
    'actual captured public alert detail at320 text200 retains workflow evidence and verified guidance',
    (tester) async {
      expect(captured, isNotNull);
      expect(guidance, isNotNull);
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        wrapScreen(
          Scaffold(
            body: SingleChildScrollView(
              child: AlertDetailContent(
                alert: captured!,
                onRefresh: () {},
                onOlder: () {},
              ),
            ),
          ),
          overrides: [
            emergencyGuidanceProvider.overrideWith((_) async => guidance!),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Status: Ditutup'), findsOneWidget);
      expect(
        find.textContaining('tidak menyatakan pasien sembuh'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
