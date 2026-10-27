import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncare_flutter/core/api_exception.dart';
import 'package:syncare_flutter/features/patient/alert_providers.dart';
import 'package:syncare_flutter/features/patient/alert_detail_screen.dart';
import 'package:syncare_flutter/features/patient/checkin_providers.dart';
import 'package:syncare_flutter/models/escalation.dart';
import '../../helpers/escalation_fixture.dart';
import '../../helpers/checkin_fixture.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

void main() {
  test(
    'patient projection rejects private fields, invalid status/evidence and future timeline versions',
    () {
      for (final status in [
        'PENDING_REVIEW',
        'ACKNOWLEDGED',
        'IN_PROGRESS',
        'RESOLVED',
      ]) {
        expect(escalationFixture(status: status).status.label, isNotEmpty);
      }
      for (final field in [
        'internalNote',
        'actorId',
        'actionType',
        'patientName',
      ]) {
        expect(
          () => Escalation.fromJson({
            ...escalationJson(),
            field: 'MUST NOT RENDER',
          }, detail: true),
          throwsA(isA<InvalidResponseException>()),
        );
      }
      final private = escalationJson(status: 'IN_PROGRESS');
      (private['timeline'] as List)[2]['internalNote'] = 'PRIVATE';
      expect(
        () => Escalation.fromJson(private, detail: true),
        throwsA(isA<InvalidResponseException>()),
      );
      for (final patch in [
        {'status': 'UNKNOWN'},
        {'status': 'RESOLVED', 'resolvedAt': null},
        {'acknowledgedAt': 'invalid'},
        {'urgency': 'guessed-high-risk'},
      ]) {
        expect(
          () => Escalation.fromJson({
            ...escalationJson(),
            ...patch,
          }, detail: true),
          throwsA(isA<InvalidResponseException>()),
        );
      }
    },
  );
  test(
    'own history deduplicates pages, retains allowed stale content on network failure and clears denied data',
    () async {
      final api = FakeSyncareApi()
        ..onListEscalations = (p, c) async => EscalationPage([
          escalationFixture(),
          if (c != null) escalationFixture(id: 'alert-b'),
        ], c == null ? 'next' : null);
      final controller = AlertHistory(api, 'patient-a');
      addTearDown(controller.dispose);
      await controller.load();
      await controller.load(next: true);
      expect(controller.state.valueOrNull!.alerts.length, 2);
      api.onListEscalations = (_, _) async => throw const NetworkException();
      await controller.load();
      expect(controller.state.hasError, true);
      expect(controller.state.valueOrNull!.alerts.length, 2);
      api.onListEscalations = (_, _) async => throw const ForbiddenException();
      await controller.load();
      expect(controller.state.valueOrNull, isNull);
      api.onListEscalations = (_, _) async =>
          EscalationPage([escalationFixture(patientId: 'foreign')], null);
      await controller.load();
      expect(controller.state.hasError, true);
      expect(controller.state.valueOrNull, isNull);
    },
  );
  test(
    'detail older-page status drift reloads actual current state; disposal ignores late read and private denial clears cache',
    () async {
      final initial = escalationFixture().withHistory(
        escalationFixture().timeline,
        'older',
      );
      var calls = 0;
      final api = FakeSyncareApi()
        ..onGetEscalation = (_, c) async {
          calls++;
          return calls == 1 ? initial : escalationFixture(status: 'RESOLVED');
        };
      final controller = AlertDetailController(api, 'patient-a', 'alert-a');
      await controller.load();
      await controller.load(older: true);
      expect(calls, 3);
      expect(controller.state.valueOrNull!.status, EscalationStatus.resolved);
      api.onGetEscalation = (_, _) async => throw const NotFoundException();
      await controller.load();
      expect(controller.state.valueOrNull, isNull);
      controller.dispose();
      final pending = Completer<Escalation>();
      api.onGetEscalation = (_, _) => pending.future;
      final later = AlertDetailController(api, 'patient-a', 'alert-a');
      final loading = later.load();
      later.dispose();
      pending.complete(initial);
      await loading;
    },
  );
  testWidgets(
    'four stored workflow states render public evidence/guidance at320 text200 without clinical recovery or action controls',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final status in [
        'PENDING_REVIEW',
        'ACKNOWLEDGED',
        'IN_PROGRESS',
        'RESOLVED',
      ]) {
        final alert = escalationFixture(status: status);
        final api = FakeSyncareApi()..onGetEscalation = (_, _) async => alert;
        await tester.pumpWidget(
          wrapScreen(
            const AlertDetailScreen(alertId: 'alert-a'),
            overrides: [
              alertDetailProvider('alert-a').overrideWith(
                (_) =>
                    AlertDetailController(api, 'patient-a', 'alert-a')..load(),
              ),
              emergencyGuidanceProvider.overrideWith(
                (_) async => guidanceFixture,
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Status: ${alert.status.label}'), findsOneWidget);
        expect(
          find.textContaining('Alasan akut sintetis asli F2.'),
          findsOneWidget,
        );
        expect(find.text('Akui alert'), findsNothing);
        expect(find.text('Tutup alert'), findsNothing);
        expect(tester.takeException(), isNull);
        if (status == 'RESOLVED') {
          expect(
            find.textContaining('tidak menyatakan pasien sembuh'),
            findsOneWidget,
          );
        }
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
  testWidgets(
    'empty own list has honest empty state and refresh, denied detail has retry without cached reason',
    (tester) async {
      final api = FakeSyncareApi()
        ..onListEscalations = (_, _) async => const EscalationPage([], null);
      await tester.pumpWidget(
        wrapScreen(
          const AlertHistoryScreen(),
          overrides: [
            alertHistoryProvider.overrideWith(
              (_) => AlertHistory(api, 'patient-a')..load(),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Belum ada alert tersimpan'), findsOneWidget);
      expect(find.text('Muat ulang tindak lanjut'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      api.onGetEscalation = (_, _) async => throw const ForbiddenException();
      await tester.pumpWidget(
        wrapScreen(
          const AlertDetailScreen(alertId: 'alert-a'),
          overrides: [
            alertDetailProvider('alert-a').overrideWith(
              (_) => AlertDetailController(api, 'patient-a', 'alert-a')..load(),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Alasan akut sintetis'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
