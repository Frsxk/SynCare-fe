import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncare_flutter/core/providers.dart';
import 'package:syncare_flutter/features/patient/plan_items.dart';
import 'package:syncare_flutter/features/patient/plan_screen.dart';
import 'package:syncare_flutter/models/approved_plan.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

const String _instruction =
    'Kontrol pada 2026-10-30 di poli jantung. '
    'Hubungi kontak rutin 1500-HOME.';

/// The exact narrative shape stored by the approved-plan workflow for the
/// synthetic demo. The medication list uses `;` and must stay one clinical
/// clause, including the `2.5mg` decimal.
const String _narrative =
    'Draf tindak lanjut. Diagnosis tercatat: demam berdarah dengue. '
    'Daftar obat dari ringkasan pulang: parasetamol 500 mg tiga kali sehari; '
    'oralit. Check-in setiap 2 hari. Kunjungan rawat jalan dalam 7 hari. '
    'Ini rencana demo sintetis yang menunggu persetujuan manusia, bukan '
    'panduan klinis.';

const String _medicationClause =
    'Daftar obat dari ringkasan pulang: parasetamol 500 mg tiga kali sehari; '
    'oralit.';

ApprovedPlanRecord _record({
  String planText = _narrative,
  List<String> careIntensity = const <String>[
    'Check-in setiap 2 hari.',
    'Kunjungan rawat jalan dalam 7 hari.',
  ],
  Map<String, dynamic>? satuseshat,
}) {
  return ApprovedPlanRecord(
    patientId: 'demo-1',
    plan: ApprovedPlan(
      planText: planText,
      satuseshat:
          satuseshat ??
          const <String, dynamic>{
            'careplan': <String, dynamic>{
              'activity': <String>[
                'Check-in setiap 2 hari.',
                'Kunjungan rawat jalan dalam 7 hari.',
              ],
            },
            'servicerequest': <String, dynamic>{
              'patientInstruction': _instruction,
              'priority': 'routine',
            },
            'task': <Object>[],
          },
      patientId: 'demo-1',
      tier: 'MEDIUM',
      careIntensity: careIntensity,
      status: 'DRAFT pending human approval',
    ),
    approvedAt: DateTime(2026, 10, 9, 16, 49),
    reviewerNote: '',
    planJsonString: '{}',
  );
}

Future<void> _pumpPlan(WidgetTester tester, ApprovedPlanRecord record) async {
  final FakeSyncareApi fake = FakeSyncareApi()
    ..onGetPlan = (_) async => record;
  await tester.pumpWidget(
    wrapScreen(
      const LegacyPatientPlanScreen(),
      overrides: <Override>[apiProvider.overrideWithValue(fake)],
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('planTextItems', () {
    test('splits semicolon-delimited steps into ordered items', () {
      expect(
        planTextItems(
          'Telepon perawat dalam 24 jam; Check-in setiap hari.',
        ),
        <String>['Telepon perawat dalam 24 jam', 'Check-in setiap hari.'],
      );
      expect(
        planTextItems('Minum obat teratur; kontrol minggu depan.'),
        <String>['Minum obat teratur', 'kontrol minggu depan.'],
      );
    });

    test('splits newlines, real bullets and numbered bullets', () {
      expect(
        planTextItems(
          '• Telepon perawat dalam 24 jam.\n'
          '• Check-in setiap hari.',
        ),
        <String>['Telepon perawat dalam 24 jam.', 'Check-in setiap hari.'],
      );
      expect(
        planTextItems(
          '1. Telepon perawat dalam 24 jam.\n'
          '2) Check-in setiap hari.',
        ),
        <String>['Telepon perawat dalam 24 jam.', 'Check-in setiap hari.'],
      );
      expect(
        planTextItems(
          '• Telepon perawat dalam 24 jam. • Check-in setiap hari.',
        ),
        <String>['Telepon perawat dalam 24 jam.', 'Check-in setiap hari.'],
      );
    });

    test('keeps medication semicolons, decimals and dose text intact', () {
      expect(
        planTextItems(
          'Daftar obat dari ringkasan pulang: furosemide 40mg 2x1; '
          'bisoprolol 2.5mg 1x1; ramipril 5mg 1x1. '
          'Telepon perawat dalam 24 jam.',
        ),
        <String>[
          'Daftar obat dari ringkasan pulang: furosemide 40mg 2x1; '
              'bisoprolol 2.5mg 1x1; ramipril 5mg 1x1.',
          'Telepon perawat dalam 24 jam.',
        ],
      );
    });

    test('preserves ordinary punctuation, dates and phone text', () {
      expect(
        planTextItems(
          'Kontrol pada 2026-10-30 di poli jantung. '
          'Hubungi kontak rutin 1500-HOME.',
        ),
        <String>[
          'Kontrol pada 2026-10-30 di poli jantung.',
          'Hubungi kontak rutin 1500-HOME.',
        ],
      );
      expect(
        planTextItems('Pemantauan ketat selama 7 hari.'),
        <String>['Pemantauan ketat selama 7 hari.'],
      );
    });

    test('returns no items for empty or whitespace text', () {
      expect(planTextItems(''), isEmpty);
      expect(planTextItems('   \n  '), isEmpty);
    });
  });

  group('planStructuredItems', () {
    test('uses ordered careplan activity and strips list markers', () {
      const ApprovedPlan plan = ApprovedPlan(
        careIntensity: <String>['Lama'],
        satuseshat: <String, dynamic>{
          'careplan': <String, dynamic>{
            'activity': <String>[
              '1. Telepon perawat dalam 24 jam.',
              '2. Check-in setiap hari.',
            ],
          },
        },
      );
      expect(
        planStructuredItems(plan),
        <String>['Telepon perawat dalam 24 jam.', 'Check-in setiap hari.'],
      );
    });

    test('skips map-shaped activity entries without stringifying them', () {
      const ApprovedPlan plan = ApprovedPlan(
        satuseshat: <String, dynamic>{
          'careplan': <String, dynamic>{
            'activity': <Object>[
              <String, String>{'text': 'bukan item teks'},
              'Telepon perawat dalam 24 jam.',
            ],
          },
        },
      );
      expect(
        planStructuredItems(plan),
        <String>['Telepon perawat dalam 24 jam.'],
      );
    });

    test('falls back to care intensity when activity is absent', () {
      const ApprovedPlan plan = ApprovedPlan(
        careIntensity: <String>['Telepon 48 jam', 'Kunjungan 7 hari'],
      );
      expect(
        planStructuredItems(plan),
        <String>['Telepon 48 jam', 'Kunjungan 7 hari'],
      );
    });

    test('returns no structured items when the plan has no arrays', () {
      const ApprovedPlan plan = ApprovedPlan();
      expect(planStructuredItems(plan), isEmpty);
    });
  });

  testWidgets(
    'renders plan steps as separate accessible items without splitting the medication clause',
    (tester) async {
      final semantics = tester.ensureSemantics();
      addTearDown(semantics.dispose);
      await _pumpPlan(tester, _record());

      expect(find.text(_narrative), findsNothing);

      final Finder planCard = find.ancestor(
        of: find.text('Rencana tindak lanjut'),
        matching: find.byType(Card),
      );
      expect(
        find.descendant(
          of: planCard,
          matching: find.text('Draf tindak lanjut.'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: planCard,
          matching: find.text('Diagnosis tercatat: demam berdarah dengue.'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: planCard, matching: find.text(_medicationClause)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: planCard,
          matching: find.text('Check-in setiap 2 hari.'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: planCard,
          matching: find.text('Kunjungan rawat jalan dalam 7 hari.'),
        ),
        findsOneWidget,
      );

      // The medication clause stays whole: no dangling `oralit.` bullet.
      expect(find.text('oralit.'), findsNothing);
      expect(
        find.bySemanticsLabel(_medicationClause),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Check-in setiap 2 hari.'),
        findsWidgets,
      );
    },
  );

  testWidgets('structured care intensity strips its own list markers', (
    tester,
  ) async {
    await _pumpPlan(
      tester,
      _record(
        careIntensity: const <String>[
          '• Telepon 48 jam',
          '2. Kunjungan 7 hari',
        ],
        satuseshat: const <String, dynamic>{
          'careplan': <String, dynamic>{},
          'servicerequest': <String, dynamic>{
            'patientInstruction': _instruction,
          },
          'task': <Object>[],
        },
      ),
    );

    expect(find.text('Telepon 48 jam'), findsOneWidget);
    expect(find.text('Kunjungan 7 hari'), findsOneWidget);
    expect(find.text('• Telepon 48 jam'), findsNothing);
    expect(find.text('2. Kunjungan 7 hari'), findsNothing);
  });

  testWidgets('empty plan text still shows the missing-value copy', (
    tester,
  ) async {
    await _pumpPlan(tester, _record(planText: '   '));
    expect(find.text('Tidak tersedia'), findsWidgets);
  });

  testWidgets('patient instruction remains one unparsed paragraph', (
    tester,
  ) async {
    await _pumpPlan(tester, _record());
    expect(find.text('Instruksi pasien'), findsOneWidget);
    expect(find.text(_instruction), findsOneWidget);
  });

  testWidgets('list wraps at 320dp with text scale 2 without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await _pumpPlan(tester, _record());
    expect(tester.takeException(), isNull);
    expect(find.text(_medicationClause), findsOneWidget);
    expect(
      find.text('Kunjungan rawat jalan dalam 7 hari.'),
      findsWidgets,
    );
  });
}
