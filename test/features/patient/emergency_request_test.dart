import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncare_flutter/core/api_exception.dart';
import 'package:syncare_flutter/features/patient/alert_detail_screen.dart';
import 'package:syncare_flutter/features/patient/alert_providers.dart';
import 'package:syncare_flutter/features/patient/checkin_providers.dart';
import 'package:syncare_flutter/features/patient/emergency_request.dart';
import 'package:syncare_flutter/models/escalation.dart';
import '../../helpers/checkin_fixture.dart';
import '../../helpers/escalation_fixture.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

final _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

Widget _panel(EmergencyRequestController controller) => wrapScreen(
      const Scaffold(
        body: SingleChildScrollView(child: EmergencyRequestPanel()),
      ),
      overrides: [
        emergencyRequestProvider.overrideWith((_) => controller),
        emergencyGuidanceProvider.overrideWith((_) async => guidanceFixture),
      ],
    );

void main() {
  test(
    'confirmed submit uses own patient, trimmed reason, UUID key and ignores a double tap',
    () async {
      final pending = Completer<EmergencyRequestResult>();
      final calls = <({String patientId, String reason, String key})>[];
      final api = FakeSyncareApi()
        ..onRequestEmergency = (patientId, reason, key) {
          calls.add((patientId: patientId, reason: reason, key: key));
          return pending.future;
        };
      final controller = EmergencyRequestController(api, 'patient-a');
      addTearDown(controller.dispose);
      final first = controller.submit('  Sesak berat sejak tadi.  ');
      await controller.submit('Sesak berat sejak tadi.');
      expect(calls, hasLength(1));
      expect(calls.single.patientId, 'patient-a');
      expect(calls.single.reason, 'Sesak berat sejak tadi.');
      expect(calls.single.key, matches(_uuidV4));
      expect(controller.state, isA<EmergencyRequestSending>());
      pending.complete(
        EmergencyRequestResult(
          alert: patientRequestFixture(reason: 'Sesak berat sejak tadi.'),
          replayed: false,
        ),
      );
      await first;
      expect(controller.state, isA<EmergencyRequestSaved>());
      expect((controller.state as EmergencyRequestSaved).replayed, isFalse);
    },
  );

  test(
    'unknown outcome keeps key and payload, refuses edited resend, retries the same key and reports replay',
    () async {
      final keys = <String>[], reasons = <String>[];
      var calls = 0;
      final api = FakeSyncareApi()
        ..onRequestEmergency = (patientId, reason, key) async {
          calls++;
          keys.add(key);
          reasons.add(reason);
          if (calls == 1) throw const NetworkException();
          return EmergencyRequestResult(
            alert: patientRequestFixture(reason: reason),
            replayed: true,
          );
        };
      final controller = EmergencyRequestController(api, 'patient-a');
      addTearDown(controller.dispose);
      await controller.submit('Nyeri dada berat.');
      expect(controller.state, isA<EmergencyRequestUnknown>());
      expect((controller.state as EmergencyRequestUnknown).reason, 'Nyeri dada berat.');
      await controller.submit('Alasan lain yang diedit.');
      expect(calls, 1, reason: 'edited text must not mint a new intent');
      await controller.retrySame();
      expect(calls, 2);
      expect(keys[1], keys[0]);
      expect(reasons[1], reasons[0]);
      expect(controller.state, isA<EmergencyRequestSaved>());
      expect((controller.state as EmergencyRequestSaved).replayed, isTrue);
    },
  );

  test(
    'validation keeps an editable draft with a new key; denied access is unavailable',
    () async {
      final keys = <String>[];
      var calls = 0;
      final api = FakeSyncareApi()
        ..onRequestEmergency = (patientId, reason, key) async {
          calls++;
          keys.add(key);
          if (calls == 1) throw const ValidationException('Alasan wajib diisi.');
          return EmergencyRequestResult(
            alert: patientRequestFixture(reason: reason),
            replayed: false,
          );
        };
      final controller = EmergencyRequestController(api, 'patient-a');
      addTearDown(controller.dispose);
      await controller.submit('x');
      expect(controller.state, isA<EmergencyRequestDraft>());
      expect((controller.state as EmergencyRequestDraft).error, isA<ValidationException>());
      expect(controller.draftReason, 'x');
      await controller.submit('Alasan yang diperbaiki.');
      expect(calls, 2);
      expect(keys[1], isNot(keys[0]));
      expect(controller.state, isA<EmergencyRequestSaved>());

      final denied = EmergencyRequestController(
        FakeSyncareApi()
          ..onRequestEmergency = (_, _, _) => throw const ForbiddenException(),
        'patient-a',
      );
      addTearDown(denied.dispose);
      await denied.submit('Nyeri dada.');
      expect(denied.state, isA<EmergencyRequestUnavailable>());
    },
  );

  test('late success after dispose is ignored and cannot resurrect state', () async {
    final pending = Completer<EmergencyRequestResult>();
    final api = FakeSyncareApi()
      ..onRequestEmergency = (_, _, _) => pending.future;
    final controller = EmergencyRequestController(api, 'patient-a');
    final call = controller.submit('Nyeri dada.');
    controller.dispose();
    pending.complete(
      EmergencyRequestResult(alert: patientRequestFixture(), replayed: false),
    );
    await call;
  });

  testWidgets(
    'cancel in the confirm dialog sends zero POST and keeps the typed reason',
    (tester) async {
      var calls = 0;
      final api = FakeSyncareApi()
        ..onRequestEmergency = (_, _, _) async {
          calls++;
          return EmergencyRequestResult(
            alert: patientRequestFixture(),
            replayed: false,
          );
        };
      final controller = EmergencyRequestController(api, 'patient-a');
      await tester.pumpWidget(_panel(controller));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Nyeri dada berat.');
      await tester.tap(find.text('Minta bantuan segera'));
      await tester.pumpAndSettle();
      expect(find.text('Kirim permintaan ke perawat?'), findsOneWidget);
      expect(find.textContaining('bukan panggilan ambulans'), findsWidgets);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.byType(AlertDialog), findsNothing);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'Nyeri dada berat.');
    },
  );

  testWidgets(
    'confirm posts once, shows the nurse-queue status and makes the reset visible',
    (tester) async {
      final keys = <String>[], reasons = <String>[];
      final api = FakeSyncareApi()
        ..onRequestEmergency = (patientId, reason, key) async {
          keys.add(key);
          reasons.add(reason);
          return EmergencyRequestResult(
            alert: patientRequestFixture(reason: reason),
            replayed: false,
          );
        };
      final controller = EmergencyRequestController(api, 'patient-a');
      await tester.pumpWidget(_panel(controller));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Sesak berat sejak tadi.');
      await tester.tap(find.text('Minta bantuan segera'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ya, kirim permintaan'));
      await tester.pumpAndSettle();
      expect(keys, hasLength(1));
      expect(keys.single, matches(_uuidV4));
      expect(reasons.single, 'Sesak berat sejak tadi.');
      expect(find.text('Permintaan tercatat'), findsOneWidget);
      expect(find.text('Status: Menunggu review'), findsOneWidget);
      expect(find.text('Sesak berat sejak tadi.'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(
        find.text(
          'Permintaan dicatat untuk perawat; bukan panggilan ambulans/tidak menjamin bantuan segera',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('119'), findsNothing);
      expect(find.textContaining('Panggil ambulans'), findsNothing);
    },
  );

  testWidgets(
    'double tap on the trigger opens one confirmation and still issues one POST',
    (tester) async {
      final pending = Completer<EmergencyRequestResult>();
      var calls = 0;
      final api = FakeSyncareApi()
        ..onRequestEmergency = (patientId, reason, key) {
          calls++;
          return pending.future;
        };
      final controller = EmergencyRequestController(api, 'patient-a');
      await tester.pumpWidget(_panel(controller));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Nyeri dada.');
      await tester.tap(find.text('Minta bantuan segera'));
      await tester.tap(
        find.text('Minta bantuan segera'),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Ya, kirim permintaan'));
      await tester.pump();
      await tester.tap(find.text('Ya, kirim permintaan'), warnIfMissed: false);
      await tester.pump();
      expect(calls, 1);
      pending.complete(
        EmergencyRequestResult(alert: patientRequestFixture(), replayed: false),
      );
      await tester.pumpAndSettle();
      expect(find.text('Permintaan tercatat'), findsOneWidget);
    },
  );

  testWidgets(
    'API error state locks the form and offers only same-key reconciliation',
    (tester) async {
      final keys = <String>[];
      var calls = 0;
      final api = FakeSyncareApi()
        ..onRequestEmergency = (patientId, reason, key) async {
          calls++;
          keys.add(key);
          if (calls == 1) throw const NetworkException();
          return EmergencyRequestResult(
            alert: patientRequestFixture(reason: reason),
            replayed: true,
          );
        };
      final controller = EmergencyRequestController(api, 'patient-a');
      await tester.pumpWidget(_panel(controller));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Nyeri dada berat.');
      await tester.tap(find.text('Minta bantuan segera'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ya, kirim permintaan'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.textContaining('Hasil permintaan belum dapat dipastikan'), findsOneWidget);
      expect(find.text('Periksa permintaan yang sama'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Nyeri dada berat.'), findsOneWidget);
      await tester.tap(find.text('Periksa permintaan yang sama'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(keys[1], keys[0]);
      expect(find.text('Permintaan tercatat'), findsOneWidget);
      expect(
        find.textContaining('Tidak ada permintaan duplikat yang dibuat'),
        findsOneWidget,
      );
    },
  );

  testWidgets('copy and controls survive 320dp at 200 percent text', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final api = FakeSyncareApi()
      ..onRequestEmergency = (_, _, _) async => EmergencyRequestResult(
        alert: patientRequestFixture(),
        replayed: false,
      );
    final controller = EmergencyRequestController(api, 'patient-a');
    await tester.pumpWidget(_panel(controller));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Permintaan dicatat untuk perawat; bukan panggilan ambulans/tidak menjamin bantuan segera',
      ),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Minta bantuan segera'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Minta bantuan segera'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'history keeps F2 rows and renders patient requests without report or attempt links',
    (tester) async {
      final api = FakeSyncareApi()
        ..onListEscalations = (_, _) async => EscalationPage([
          escalationFixture(),
          patientRequestFixture(),
        ], null);
      final requestApi = FakeSyncareApi()
        ..onRequestEmergency = (_, _, _) async => EmergencyRequestResult(
          alert: patientRequestFixture(),
          replayed: false,
        );
      final requestController = EmergencyRequestController(
        requestApi,
        'patient-a',
      );
      await tester.pumpWidget(
        wrapScreen(
          const AlertHistoryScreen(),
          overrides: [
            alertHistoryProvider.overrideWith(
              (_) => AlertHistory(api, 'patient-a')..load(),
            ),
            emergencyRequestProvider.overrideWith((_) => requestController),
            emergencyGuidanceProvider.overrideWith((_) async => guidanceFixture),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Laporan:'), findsOneWidget);
      expect(find.textContaining('Permintaan darurat:'), findsOneWidget);
      expect(find.textContaining('report-a'), findsNothing);
      expect(find.textContaining('attempt-a'), findsNothing);
      expect(find.text('Minta bantuan segera'), findsWidgets);
    },
  );

  testWidgets(
    'patient request detail uses request provenance and no F2 report wording',
    (tester) async {
      final alert = patientRequestFixture(status: 'ACKNOWLEDGED');
      final api = FakeSyncareApi()..onGetEscalation = (_, _) async => alert;
      await tester.pumpWidget(
        wrapScreen(
          const AlertDetailScreen(alertId: 'alert-request-a'),
          overrides: [
            alertDetailProvider('alert-request-a').overrideWith(
              (_) => AlertDetailController(api, 'patient-a', 'alert-request-a')
                ..load(),
            ),
            emergencyGuidanceProvider.overrideWith((_) async => guidanceFixture),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Permintaan darurat:'), findsOneWidget);
      expect(find.textContaining('Laporan:'), findsNothing);
      expect(find.textContaining('report-a'), findsNothing);
      expect(find.textContaining('attempt-a'), findsNothing);
    },
  );
}
