import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncare_flutter/core/api_exception.dart';
import 'package:syncare_flutter/features/patient/approved_plan_providers.dart';
import 'package:syncare_flutter/features/patient/plan_screen.dart';
import 'package:syncare_flutter/models/verified_care_plan.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/verified_plan_fixture.dart';

void main() {
  test(
    'verified plan strictly rejects absent date, private notes, source mismatch and unguarded content',
    () {
      final valid = verifiedPlanFixture();
      expect(valid.approvedLabel, '2026-10-26 10:00 WIB');
      expect(valid.record.plan.status, 'DRAFT pending human approval');
      for (final patch in [
        {'approvedAt': null},
        {'approvedAt': ''},
        {'approvedAt': 'not a date'},
        {'approvedAt': '2026-02-30T03:00:00.000Z'},
        {'reviewer_note': 'INTERNAL'},
        {'patientId': 'other'},
      ]) {
        expect(
          () => VerifiedCarePlan.fromJson({...verifiedPlanJson(), ...patch}),
          throwsA(isA<InvalidResponseException>()),
        );
      }
      final hidden = verifiedPlanJson();
      (hidden['plan'] as Map)['source_input'] = {'reviewer_note': 'private'};
      expect(
        () => VerifiedCarePlan.fromJson(hidden),
        throwsA(isA<InvalidResponseException>()),
      );
    },
  );
  test(
    'safe own paging retains network cache, clears denial and ignores disposed reads',
    () async {
      final api = FakeSyncareApi()
        ..onListVerifiedPlans = (_, c) async => VerifiedPlanPage([
          verifiedPlanFixture(),
          if (c != null) verifiedPlanFixture(id: 'approval-b'),
        ], c == null ? 'next' : null);
      final controller = VerifiedPlans(api, 'patient-a');
      await controller.load();
      await controller.load(next: true);
      expect(controller.state.valueOrNull!.plans.length, 2);
      api.onListVerifiedPlans = (_, _) async => throw const NetworkException();
      await controller.load();
      expect(controller.state.valueOrNull!.plans.length, 2);
      api.onListVerifiedPlans = (_, _) async =>
          throw const ForbiddenException();
      await controller.load();
      expect(controller.state.valueOrNull, isNull);
      controller.dispose();
      final pending = Completer<VerifiedPlanPage>();
      api.onListVerifiedPlans = (_, _) => pending.future;
      final later = VerifiedPlans(api, 'patient-a'), read = later.load();
      later.dispose();
      pending.complete(VerifiedPlanPage([verifiedPlanFixture()], null));
      await read;
    },
  );
  testWidgets(
    'verified patient content at320 text200 preserves evidence and historical warning without internal notes',
    (tester) async {
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
              page: VerifiedPlanPage([
                verifiedPlanFixture(applicable: false),
              ], null),
              onRefresh: () {},
              onNext: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Persetujuan terverifikasi:'), findsOneWidget);
      expect(find.textContaining('sumber pulang sebelumnya'), findsOneWidget);
      for (final card in find.byType(Card).evaluate()) {
        expect(
          tester.getSize(find.byWidget(card.widget)).width,
          greaterThanOrEqualTo(288),
        );
      }
      expect(find.text('Catatan peninjau'), findsNothing);
      expect(find.text('Detail persetujuan'), findsNothing);
      expect(find.text('Detail SATUSEHAT'), findsNothing);
      expect(find.textContaining('DRAFT pending human approval'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Disetujui perawat (simulasi)'),
        350,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'current plan screen has loading/empty/error retry and no fallback patient identity',
    (tester) async {
      final api = FakeSyncareApi()
        ..onListVerifiedPlans = (_, _) async =>
            const VerifiedPlanPage([], null);
      await tester.pumpWidget(
        wrapScreen(
          const PatientPlanScreen(),
          overrides: [
            verifiedPlansProvider.overrideWith(
              (_) => VerifiedPlans(api, 'patient-a')..load(),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Belum ada rencana terverifikasi'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      api.onListVerifiedPlans = (_, _) async => throw const NetworkException();
      await tester.pumpWidget(
        wrapScreen(
          const PatientPlanScreen(),
          overrides: [
            verifiedPlansProvider.overrideWith(
              (_) => VerifiedPlans(api, 'patient-a')..load(),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Coba lagi'), findsOneWidget);
      expect(find.text('Belum ada rencana terverifikasi'), findsNothing);
    },
  );
}
