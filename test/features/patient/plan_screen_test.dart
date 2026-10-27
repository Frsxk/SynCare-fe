import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncare_flutter/core/api_exception.dart';
import 'package:syncare_flutter/core/providers.dart';
import 'package:syncare_flutter/features/patient/plan_screen.dart';
import 'package:syncare_flutter/models/approved_plan.dart';
import 'package:syncare_flutter/widgets/disclaimer_banner.dart';
import 'package:syncare_flutter/widgets/empty_state.dart';
import 'package:syncare_flutter/widgets/error_state.dart';
import 'package:syncare_flutter/widgets/risk_badge.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

const String _instruction =
    'Kontrol pada 2026-10-30 di poli jantung. '
    'Hubungi kontak rutin 1500-HOME.';

ApprovedPlanRecord _record() {
  return ApprovedPlanRecord(
    patientId: 'demo-1',
    plan: const ApprovedPlan(
      planText: 'Pemantauan ketat selama 7 hari.',
      satuseshat: <String, dynamic>{
        'careplan': <String, dynamic>{
          'resourceType': 'CarePlan',
          'status': 'draft',
        },
        'servicerequest': <String, dynamic>{
          'resourceType': 'ServiceRequest',
          'patientInstruction': _instruction,
        },
        'task': <String, dynamic>{'resourceType': 'Task', 'status': 'draft'},
      },
      patientId: 'demo-1',
      tier: 'HIGH',
      careIntensity: <String>['Telepon 48 jam', 'Kunjungan 7 hari'],
      status: 'DRAFT pending human approval',
    ),
    approvedAt: DateTime(2026, 10, 9, 16, 49),
    reviewerNote: 'Disetujui.',
    planJsonString: '{}',
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<FakeSyncareApi> pumpScreen(
    WidgetTester tester, {
    required Future<ApprovedPlanRecord> Function(String patientId) onGetPlan,
  }) async {
    final FakeSyncareApi fake = FakeSyncareApi()..onGetPlan = onGetPlan;
    await tester.pumpWidget(
      wrapScreen(
        const LegacyPatientPlanScreen(),
        overrides: <Override>[apiProvider.overrideWithValue(fake)],
      ),
    );
    return fake;
  }

  testWidgets(
    'renders care instructions without backend artifacts or private notes',
    (tester) async {
      await pumpScreen(tester, onGetPlan: (_) async => _record());
      await tester.pumpAndSettle();

      expect(find.text('Rencana Saya'), findsOneWidget);
      expect(find.byType(DisclaimerBanner), findsOneWidget);
      expect(find.text('ID Pasien: demo-1'), findsNothing);
      expect(find.text('Pemantauan ketat selama 7 hari.'), findsOneWidget);
      expect(find.byType(RiskBadge), findsOneWidget);
      expect(find.text('HIGH'), findsOneWidget);

      expect(find.text('Intensitas perawatan'), findsOneWidget);
      expect(find.text('Telepon 48 jam'), findsOneWidget);
      expect(find.text('Kunjungan 7 hari'), findsOneWidget);

      expect(find.text('09/10/2026 16:49'), findsOneWidget);
      expect(find.text('Disetujui.'), findsNothing);
      expect(find.text('Disetujui perawat (simulasi)'), findsOneWidget);
      expect(find.text('Status: DRAFT pending human approval'), findsNothing);

      final double bannerTop = tester
          .getTopLeft(find.byType(DisclaimerBanner))
          .dy;
      final double planTop = tester
          .getTopLeft(find.text('Pemantauan ketat selama 7 hari.'))
          .dy;
      expect(bannerTop, lessThan(planTop));

      expect(find.text('Detail SATUSEHAT'), findsNothing);
      expect(find.textContaining('"resourceType"'), findsNothing);
      expect(find.text('Catatan peninjau'), findsNothing);
    },
  );

  testWidgets('shows the follow-up date and hotline from the instruction', (
    tester,
  ) async {
    await pumpScreen(tester, onGetPlan: (_) async => _record());
    await tester.pumpAndSettle();

    expect(find.text('Instruksi pasien'), findsOneWidget);
    expect(find.text(_instruction), findsOneWidget);
    expect(find.text('Tanggal tindak lanjut'), findsOneWidget);
    expect(find.text('2026-10-30'), findsOneWidget);
    expect(find.text('Hotline'), findsOneWidget);
    expect(find.text('1500-HOME'), findsOneWidget);
  });

  testWidgets('renders an empty state for a 404', (tester) async {
    await pumpScreen(
      tester,
      onGetPlan: (_) async => throw const NotFoundException(),
    );
    await tester.pumpAndSettle();

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.byType(ErrorState), findsNothing);
    expect(find.text('Belum ada rencana yang disetujui'), findsOneWidget);
    expect(
      find.text(
        'Rencana akan muncul di sini setelah perawat menyetujui draf '
        'tindak lanjut.',
      ),
      findsOneWidget,
    );
    expect(find.byType(DisclaimerBanner), findsOneWidget);
  });

  testWidgets('shows the warming retry copy and refetches on retry', (
    tester,
  ) async {
    int calls = 0;
    await pumpScreen(
      tester,
      onGetPlan: (_) async {
        calls += 1;
        if (calls == 1) {
          throw const EngineWarmingException();
        }
        return _record();
      },
    );
    await tester.pumpAndSettle();

    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.byType(EmptyState), findsNothing);
    expect(find.text('Layanan sedang menyiapkan, coba lagi'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);
    expect(find.byType(DisclaimerBanner), findsOneWidget);

    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text('Pemantauan ketat selama 7 hari.'), findsOneWidget);
    expect(find.byType(ErrorState), findsNothing);
  });

  testWidgets('shows a loading state while the plan is fetched', (
    tester,
  ) async {
    final Completer<ApprovedPlanRecord> completer =
        Completer<ApprovedPlanRecord>();
    await pumpScreen(tester, onGetPlan: (_) => completer.future);
    await tester.pump();

    expect(find.text('Memuat rencana…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(DisclaimerBanner), findsOneWidget);

    completer.complete(_record());
    await tester.pumpAndSettle();

    expect(find.text('Memuat rencana…'), findsNothing);
    expect(find.text('Pemantauan ketat selama 7 hari.'), findsOneWidget);
  });
}
