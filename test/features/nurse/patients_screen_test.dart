import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncare_flutter/core/api_exception.dart';
import 'package:syncare_flutter/core/providers.dart';
import 'package:syncare_flutter/features/nurse/patients_screen.dart';
import 'package:syncare_flutter/models/approved_plan.dart';
import 'package:syncare_flutter/widgets/disclaimer_banner.dart';
import 'package:syncare_flutter/widgets/empty_state.dart';
import 'package:syncare_flutter/widgets/error_state.dart';
import 'package:syncare_flutter/widgets/risk_badge.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

ApprovedPlanRecord _fakeRecord({
  String patientId = 'chf-chain-164858',
  String tier = 'HIGH',
  String reviewerNote = 'Disetujui tanpa perubahan.',
  String planText = 'Pemantauan ketat asupan garam dan berat badan harian.',
  DateTime? approvedAt,
}) {
  return ApprovedPlanRecord(
    patientId: patientId,
    plan: ApprovedPlan(
      planText: planText,
      patientId: patientId,
      tier: tier,
      status: 'DRAFT pending human approval',
    ),
    approvedAt: approvedAt ?? DateTime(2026, 10, 23, 14, 30),
    reviewerNote: reviewerNote,
    planJsonString: '{}',
  );
}

AuditEntry _fakeAudit({
  String action = 'approve_plan',
  String actor = 'perawat-siti',
  DateTime? timestamp,
}) {
  return AuditEntry(
    action: action,
    actor: actor,
    timestamp: timestamp ?? DateTime(2026, 10, 23, 14, 35),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<FakeSyncareApi> pumpScreen(
    WidgetTester tester, {
    required Future<PlansResponse> Function() onListPlans,
  }) async {
    final FakeSyncareApi fake = FakeSyncareApi()..onListPlans = onListPlans;
    await tester.pumpWidget(
      wrapScreen(
        const NursePatientsScreen(),
        overrides: <Override>[apiProvider.overrideWithValue(fake)],
      ),
    );
    return fake;
  }

  testWidgets(
    'renders AppBar with title and refresh button, and disclaimer banner',
    (tester) async {
      await pumpScreen(tester, onListPlans: () async => const PlansResponse());
      await tester.pumpAndSettle();

      expect(find.text('Pasien & Audit'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.byType(DisclaimerBanner), findsOneWidget);
    },
  );

  testWidgets('shows loading spinner and message while fetching', (
    tester,
  ) async {
    final Completer<PlansResponse> completer = Completer<PlansResponse>();
    await pumpScreen(tester, onListPlans: () => completer.future);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Memuat daftar rencana…'), findsOneWidget);
    expect(find.byType(DisclaimerBanner), findsOneWidget);

    completer.complete(
      PlansResponse(
        plans: <ApprovedPlanRecord>[_fakeRecord()],
        audit: <AuditEntry>[_fakeAudit()],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Memuat daftar rencana…'), findsNothing);
    expect(find.text('chf-chain-164858'), findsOneWidget);
  });

  testWidgets(
    'renders patient ID, tier, action, and actor from plans and audit data',
    (tester) async {
      await pumpScreen(
        tester,
        onListPlans: () async => PlansResponse(
          plans: <ApprovedPlanRecord>[_fakeRecord()],
          audit: <AuditEntry>[_fakeAudit()],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DisclaimerBanner), findsOneWidget);
      expect(find.text('Rencana disetujui'), findsOneWidget);
      expect(find.text('chf-chain-164858'), findsOneWidget);
      expect(find.byType(RiskBadge), findsOneWidget);
      expect(find.text('HIGH'), findsOneWidget);
      expect(find.text('23/10/2026 14:30'), findsOneWidget);
      expect(find.text('Disetujui tanpa perubahan.'), findsOneWidget);
      expect(
        find.text('Pemantauan ketat asupan garam dan berat badan harian.'),
        findsOneWidget,
      );

      expect(find.text('Jejak audit'), findsOneWidget);
      expect(find.text('approve_plan'), findsOneWidget);
      expect(find.text('perawat-siti'), findsOneWidget);
      expect(find.text('23/10/2026 14:35'), findsOneWidget);

      final double bannerTop = tester
          .getTopLeft(find.byType(DisclaimerBanner))
          .dy;
      final double cardTop = tester
          .getTopLeft(find.text('chf-chain-164858'))
          .dy;
      expect(bannerTop, lessThan(cardTop));
    },
  );

  testWidgets('renders an empty state when both plans and audit are empty', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      onListPlans: () async => const PlansResponse(
        plans: <ApprovedPlanRecord>[],
        audit: <AuditEntry>[],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.byType(ErrorState), findsNothing);
    expect(find.text('Belum ada rencana disetujui'), findsOneWidget);
    expect(
      find.text(
        'Rencana yang disetujui perawat akan muncul di sini '
        'beserta jejak auditnya.',
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.folder_open_outlined), findsOneWidget);
    expect(find.byType(DisclaimerBanner), findsOneWidget);
  });

  testWidgets(
    'shows warming retry copy for EngineWarmingException and retries',
    (tester) async {
      int calls = 0;
      await pumpScreen(
        tester,
        onListPlans: () async {
          calls += 1;
          if (calls == 1) {
            throw const EngineWarmingException();
          }
          return PlansResponse(
            plans: <ApprovedPlanRecord>[_fakeRecord()],
            audit: <AuditEntry>[_fakeAudit()],
          );
        },
      );
      await tester.pumpAndSettle();

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.byType(EmptyState), findsNothing);
      expect(find.text('Layanan sedang menyiapkan, coba lagi'), findsOneWidget);
      expect(
        find.text(
          'Mesin pemrosesan belum siap. Tunggu sebentar, lalu coba lagi.',
        ),
        findsOneWidget,
      );
      expect(find.text('Coba lagi'), findsOneWidget);
      expect(find.byType(DisclaimerBanner), findsOneWidget);

      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();

      expect(calls, 2);
      expect(find.byType(ErrorState), findsNothing);
      expect(find.text('chf-chain-164858'), findsOneWidget);
    },
  );

  testWidgets('AppBar refresh button invalidates plansProvider and reloads', (
    tester,
  ) async {
    int calls = 0;
    await pumpScreen(
      tester,
      onListPlans: () async {
        calls += 1;
        return PlansResponse(
          plans: <ApprovedPlanRecord>[_fakeRecord(patientId: 'patient-$calls')],
          audit: <AuditEntry>[_fakeAudit()],
        );
      },
    );
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.text('patient-1'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text('patient-2'), findsOneWidget);
  });

  testWidgets('renders a missing-note label when the reviewer note is empty', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      onListPlans: () async => PlansResponse(
        plans: <ApprovedPlanRecord>[_fakeRecord(reviewerNote: '   ')],
        audit: <AuditEntry>[],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tidak tersedia'), findsOneWidget);
  });

  testWidgets('is read-only with no edit or delete controls', (tester) async {
    await pumpScreen(
      tester,
      onListPlans: () async => PlansResponse(
        plans: <ApprovedPlanRecord>[_fakeRecord()],
        audit: <AuditEntry>[_fakeAudit()],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.edit), findsNothing);
    expect(find.byIcon(Icons.delete), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('shows reauth option when UnauthorizedException occurs', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      onListPlans: () async => throw const UnauthorizedException(),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text('Sesi tidak valid'), findsOneWidget);
    expect(find.text('Perbarui token'), findsOneWidget);
  });
}
