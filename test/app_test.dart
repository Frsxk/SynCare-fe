import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncare_flutter/app.dart';
import 'package:syncare_flutter/core/providers.dart';
import 'package:syncare_flutter/features/auth/role_picker_screen.dart';
import 'package:syncare_flutter/models/approved_plan.dart';
import 'package:syncare_flutter/widgets/disclaimer_banner.dart';

import 'helpers/fakes.dart';

const String _patientId = 'demo-1';
const String _planText =
    'Pemantauan ketat asupan garam dan berat badan harian.';

Map<String, dynamic> _planJson() {
  return <String, dynamic>{
    'patient_id': _patientId,
    'plan_text': _planText,
    'tier': 'HIGH',
    'care_intensity': <String>['Telepon 48 jam'],
    'status': 'DRAFT pending human approval',
    'satuseshat': <String, dynamic>{
      'servicerequest': <String, dynamic>{
        'patientInstruction':
            'Kontrol pada 2026-10-30 di poli jantung. '
            'Hubungi kontak rutin 1500-HOME.',
      },
    },
  };
}

ApprovedPlanRecord _approvedPlanFromJson() {
  return ApprovedPlanRecord.fromJson(<String, dynamic>{
    'patient_id': _patientId,
    'plan_json': _planJson(),
    'approved_at': '2026-10-23T14:30:00Z',
    'reviewer_note': 'Disetujui tanpa perubahan.',
  });
}

PlansResponse _plansResponseFromJson() {
  return PlansResponse.fromJson(<String, dynamic>{
    'plans': <Map<String, dynamic>>[
      <String, dynamic>{
        'patient_id': _patientId,
        'plan_json': _planJson(),
        'approved_at': '2026-10-23T14:30:00Z',
        'reviewer_note': 'Disetujui tanpa perubahan.',
      },
    ],
    'audit': <Map<String, dynamic>>[
      <String, dynamic>{
        'action': 'approve_plan',
        'actor': 'perawat-siti',
        'timestamp': '2026-10-23T14:35:00Z',
      },
    ],
  });
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> pumpApp(WidgetTester tester, FakeSyncareApi fake) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[apiProvider.overrideWithValue(fake)],
        child: const SynCareApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapRole(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('role picker presents both roles and the demo disclaimer', (
    tester,
  ) async {
    await pumpApp(tester, FakeSyncareApi());

    expect(find.byType(RolePickerScreen), findsOneWidget);
    expect(find.text('Saya Pasien'), findsOneWidget);
    expect(find.text('Saya Perawat'), findsOneWidget);
    expect(find.byType(DisclaimerBanner), findsOneWidget);
    expect(find.text('Demo sintetis — bukan nasihat medis'), findsOneWidget);
  });

  testWidgets(
    'patient role navigates through check-in, plan, and back to the roles',
    (tester) async {
      final FakeSyncareApi fake = FakeSyncareApi()
        ..onGetPlan = (_) async => _approvedPlanFromJson();
      await pumpApp(tester, fake);

      await tapRole(tester, 'Saya Pasien');

      expect(find.text('Check-in Pasien'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Rencana'), findsOneWidget);
      expect(find.text('Tanya'), findsOneWidget);
      expect(find.text('Peran'), findsOneWidget);
      expect(find.text('Draf'), findsNothing);
      expect(find.text('Setujui'), findsNothing);

      await tester.tap(find.text('Rencana'));
      await tester.pumpAndSettle();

      expect(find.text('Rencana Saya'), findsOneWidget);
      expect(find.text(_planText), findsOneWidget);
      expect(find.text('HIGH'), findsOneWidget);

      await tester.tap(find.text('Peran'));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('Saya Pasien'), findsOneWidget);
      expect(find.text('Saya Perawat'), findsOneWidget);
    },
  );

  testWidgets(
    'nurse role switches the shell destinations and reaches the patients screen',
    (tester) async {
      final FakeSyncareApi fake = FakeSyncareApi()
        ..onListPlans = () async => _plansResponseFromJson();
      await pumpApp(tester, fake);

      await tapRole(tester, 'Saya Perawat');

      expect(find.text('Intake Perawat'), findsOneWidget);
      expect(find.text('Draf'), findsOneWidget);
      expect(find.text('Setujui'), findsOneWidget);
      expect(find.text('Pasien'), findsOneWidget);
      expect(find.text('Peran'), findsOneWidget);
      expect(find.text('Tanya'), findsNothing);
      expect(find.text('Rencana'), findsNothing);

      await tester.tap(find.text('Pasien'));
      await tester.pumpAndSettle();

      expect(find.text('Pasien & Audit'), findsOneWidget);
      expect(find.text('Rencana disetujui'), findsOneWidget);
      expect(find.text(_planText), findsOneWidget);
      expect(find.text('Jejak audit'), findsOneWidget);
      expect(find.text('approve_plan'), findsOneWidget);
      expect(find.text('perawat-siti'), findsOneWidget);
      expect(find.text(_patientId), findsOneWidget);
    },
  );
}
