import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncare_flutter/app.dart';
import 'package:syncare_flutter/core/providers.dart';
import 'package:syncare_flutter/core/api_exception.dart';
import 'package:syncare_flutter/features/auth/session_controller.dart';
import 'package:syncare_flutter/models/session.dart';
import 'package:syncare_flutter/features/patient/checkin_providers.dart';
import 'package:syncare_flutter/models/checkin_record.dart';
import 'package:syncare_flutter/core/session_api.dart';
import 'support/runtime_binding.dart';

Future<void> waitForState(
  WidgetTester tester,
  bool Function() predicate,
) async {
  final until = DateTime.now().add(const Duration(seconds: 70));
  while (!predicate() && DateTime.now().isBefore(until)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(
    predicate(),
    true,
    reason: 'Actual state did not settle; private values omitted.',
  );
}

void main() {
  final binding = SynCareIntegrationBinding();
  testWidgets(
    'actual cross-client identity and monitoring phase',
    (tester) async {
      final fixture = await binding.fixture.future, scope = ProviderContainer();
      addTearDown(scope.dispose);
      addTearDown(() async {
        if (scope.read(sessionControllerProvider) is SessionAuthenticated) {
          await scope.read(sessionControllerProvider.notifier).logout();
        }
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(container: scope, child: const SynCareApp()),
      );
      await waitForState(
        tester,
        () => scope.read(sessionControllerProvider) is SessionSignedOut,
      );
      final identities = <String>[];
      final reports = <Map<String, dynamic>>[];
      for (final value in fixture['patients'] as List) {
        final account = value as Map<String, dynamic>;
        await waitForState(
          tester,
          () => find.byType(TextField).evaluate().length == 2,
        );
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsNWidgets(2));
        await tester.enterText(
          find.byType(TextField).at(0),
          account['identifier'] as String,
        );
        await tester.enterText(
          find.byType(TextField).at(1),
          account['password'] as String,
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
        await waitForState(
          tester,
          () => scope.read(sessionControllerProvider) is SessionAuthenticated,
        );
        final principal =
            (scope.read(sessionControllerProvider) as SessionAuthenticated)
                .session
                .principal;
        expect(principal.role, 'patient');
        identities.add(principal.patientId!);
        final profile = await scope
            .read(apiProvider)
            .getPatientOverview(principal.patientId!);
        expect(profile.profile.id, principal.patientId);
        if (identities.length > 1) {
          await expectLater(
            scope.read(apiProvider).getPatientOverview(identities.first),
            throwsA(isA<NotFoundException>()),
          );
        }
        if (account['patientId'] != null) {
          expect(principal.patientId, account['patientId']);
        }
        scope.read(routerProvider).go('/nurse/approval');
        await tester.pumpAndSettle();
        expect(
          scope.read(routerProvider).routeInformationProvider.value.uri.path,
          '/account',
        );
        if (fixture['phase'] != 'smoke') {
          final baseline = account['baseline'] as Map<String, dynamic>;
          expect(
            profile.confirmedRisk.current!.assessmentId,
            baseline['assessmentId'],
          );
          expect(profile.confirmedRisk.current!.score, baseline['score']);
          final message =
              'DATA SINTETIS M10 ${fixture['runId']} ${account['slot']} Flutter. ${account['slot'] == 'low' ? 'Saya mengalami sesak napas berat saat istirahat dan nyeri dada hebat sekarang.' : 'Hari ini merasa baik, tidak ada keluhan. Obat diminum teratur.'}';
          final api = scope.read(apiProvider),
              history = await api.listCheckins(principal.patientId!);
          final existing = history.records
              .where((r) => r.message == message)
              .toList();
          expect(existing.length, lessThanOrEqualTo(1));
          CheckinRecord record;
          if (existing.isNotEmpty) {
            record = existing.single;
          } else if (account['uiReport']
              case final Map<String, dynamic> intent) {
            expect(intent['message'], message);
            record = await api.submitCheckin(
              patientId: principal.patientId!,
              message: message,
              requestKey: intent['key'] as String,
            );
          } else {
            expect(
              fixture['phase'],
              'identity_commit',
              reason: 'Restore never creates a new report.',
            );
            scope.read(routerProvider).go('/patient/checkin');
            await tester.pumpAndSettle();
            await waitForState(
              tester,
              () => find.byType(TextField).evaluate().length == 1,
            );
            await tester.enterText(find.byType(TextField), message);
            final submit = find.widgetWithText(FilledButton, 'Kirim check-in');
            await tester.ensureVisible(submit);
            await tester.tap(submit);
            await waitForState(
              tester,
              () => scope.read(checkinSubmitProvider) is CheckinSaved,
            );
            record = (scope.read(checkinSubmitProvider) as CheckinSaved).record;
          }
          for (var i = 0; i < 180 && record.processing.isPending; i++) {
            await tester.pump(const Duration(milliseconds: 500));
            record = await api.getCheckin(record.id);
          }
          expect(record.processing, ProcessingState.succeeded);
          expect(record.baseline!.assessmentId, baseline['assessmentId']);
          expect(record.baseline!.score, baseline['score']);
          expect(record.patientId, principal.patientId);
          expect(record.message, message);
          expect(
            record.outcome,
            account['slot'] == 'low'
                ? isA<UrgentCheckinOutcome>()
                : isA<RoutineCheckinOutcome>(),
          );
          scope.read(routerProvider).go('/patient/checkins/${record.id}');
          await tester.pumpAndSettle();
          await waitForState(
            tester,
            () => find.text('ID laporan: ${record.id}').evaluate().isNotEmpty,
          );
          expect(find.text(message), findsOneWidget);
          expect(find.text('Waktu kirim: ${record.createdAt}'), findsOneWidget);
          expect(
            find.text(
              'Hasil F2 tidak mengganti kategori F1 yang dikonfirmasi perawat.',
            ),
            findsOneWidget,
          );
          if (account['slot'] == 'low') {
            expect(find.text('Peringatan mendesak dari F2'), findsOneWidget);
            expect(record.alertEvidence, 'queued');
          }
          final after = await api.getPatientOverview(principal.patientId!);
          expect(
            after.confirmedRisk.current!.assessmentId,
            baseline['assessmentId'],
          );
          reports.add({
            'id': record.id,
            'patientId': record.patientId,
            'createdAt': record.createdAt,
            'message': record.message,
            'baselineScore': record.baseline!.score,
            'assessmentId': record.baseline!.assessmentId,
            'urgent': record.outcome is UrgentCheckinOutcome,
          });
        }
        final state =
            scope.read(sessionControllerProvider) as SessionAuthenticated;
        final token = scope
            .read(sessionControllerProvider.notifier)
            .tokenFor(state.generation)!;
        await scope.read(sessionControllerProvider.notifier).logout();
        await waitForState(
          tester,
          () => scope.read(sessionControllerProvider) is SessionSignedOut,
        );
        await expectLater(
          scope.read(sessionApiProvider).restore(token),
          throwsA(
            isA<SessionException>().having(
              (e) => e.failure,
              'failure',
              SessionFailure.invalidCredentials,
            ),
          ),
        );
      }
      expect(identities.toSet().length, 2);
      binding.reportData = {
        'phase': fixture['phase'],
        'actualFlutterWeb': true,
        'accounts': identities.length,
        'reports': reports,
        'roleGuard': true,
        'logoutRevoked': true,
        'nativeVerified': false,
      };
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
