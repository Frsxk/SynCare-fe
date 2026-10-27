import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncare_flutter/core/api_exception.dart';
import 'package:syncare_flutter/core/config.dart';
import 'package:syncare_flutter/core/providers.dart';
import 'package:syncare_flutter/features/nurse/draft_screen.dart';
import 'package:syncare_flutter/models/discharge_result.dart';
import 'package:syncare_flutter/models/plan_draft.dart';
import 'package:syncare_flutter/widgets/disclaimer_banner.dart';
import 'package:syncare_flutter/widgets/empty_state.dart';
import 'package:syncare_flutter/widgets/error_state.dart';
import 'package:syncare_flutter/widgets/risk_badge.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

const DischargeResult _f1 = DischargeResult(
  tier: 'HIGH',
  score: 7,
  label: 'demo-heuristic-v1',
);

const PlanDraft _draft = PlanDraft(
  planText: 'Pantau berat badan dan tanda sesak setiap hari.',
  patientId: 'demo-1',
  tier: 'HIGH',
  careIntensity: <String>['Kunjungan rumah mingguan', 'Telemonitoring harian'],
  status: 'DRAFT pending human approval',
  label: 'demo-heuristic-v1',
  disclaimer: 'Keluaran demo sintetis; bukan nasihat medis.',
);

const PlanDraft _incompleteDraft = PlanDraft(
  planText: 'Draf awal tanpa data lengkap.',
  tier: 'MEDIUM',
  careIntensity: <String>['Telemonitoring harian'],
  status: 'DRAFT pending human approval',
  missingFacts: <String>['Tanggal kontrol', 'Riwayat alergi'],
  disclaimer: 'Keluaran demo sintetis; bukan nasihat medis.',
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    required FakeSyncareApi api,
    DischargeResult? f1 = _f1,
  }) async {
    final DischargeResult? f1Value = f1;
    await tester.pumpWidget(
      wrapScreen(
        const NurseDraftScreen(),
        overrides: <Override>[
          apiProvider.overrideWithValue(api),
          f1ResultProvider.overrideWith((ref) => f1Value),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  ProviderContainer containerOf(WidgetTester tester) {
    return ProviderScope.containerOf(
      tester.element(find.byType(NurseDraftScreen)),
      listen: false,
    );
  }

  Future<void> openDatePickerAndConfirm(WidgetTester tester) async {
    final Finder dateField = find.byKey(const Key('draft-followup-date'));
    await tester.ensureVisible(dateField);
    await tester.pumpAndSettle();
    await tester.tap(dateField);
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);
    final labels = MaterialLocalizations.of(
      tester.element(find.byType(DatePickerDialog)),
    );
    await tester.tap(find.text(labels.okButtonLabel));
    await tester.pumpAndSettle();
  }

  Future<void> fillRequiredFields(
    WidgetTester tester, {
    String hotline = '1500-HOME',
  }) async {
    final Finder hotlineField = find.byKey(const Key('draft-hotline'));
    await tester.ensureVisible(hotlineField);
    await tester.pumpAndSettle();
    await tester.enterText(hotlineField, hotline);
    await tester.pump();
    await openDatePickerAndConfirm(tester);
  }

  Future<void> submit(WidgetTester tester) async {
    final Finder button = find.byKey(const Key('draft-submit'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
  }

  testWidgets('asks for an intake result when F1 is missing', (tester) async {
    final FakeSyncareApi api = FakeSyncareApi();
    await pumpScreen(tester, api: api, f1: null);

    expect(find.byType(DisclaimerBanner), findsOneWidget);
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Lakukan intake dulu'), findsOneWidget);
    expect(
      find.text(
        'Draf tindak lanjut membutuhkan hasil penilaian ringkasan pulang.',
      ),
      findsOneWidget,
    );
    expect(find.text('Ke intake'), findsOneWidget);
    expect(find.byKey(const Key('draft-patient-id')), findsNothing);

    final double bannerBottom = tester
        .getBottomLeft(find.byType(DisclaimerBanner))
        .dy;
    final double emptyTop = tester.getTopLeft(find.byType(EmptyState)).dy;
    expect(bannerBottom, lessThanOrEqualTo(emptyTop));
  });

  testWidgets(
    'collects the patient ID, follow-up date, and hotline, then renders and '
    'stores the draft',
    (tester) async {
      final FakeSyncareApi api = FakeSyncareApi();
      String? sentPatientId;
      String? sentFollowupDate;
      String? sentHotline;
      DischargeResult? sentF1;
      api.onDraftPlan =
          ({
            required String patientId,
            required String followupDate,
            required String hotline,
            required DischargeResult f1ScoredOutput,
          }) async {
            sentPatientId = patientId;
            sentFollowupDate = followupDate;
            sentHotline = hotline;
            sentF1 = f1ScoredOutput;
            return _draft;
          };

      await pumpScreen(tester, api: api);

      final TextFormField patientIdField = tester.widget<TextFormField>(
        find.byKey(const Key('draft-patient-id')),
      );
      expect(patientIdField.controller?.text, AppConfig.defaultPatientId);
      expect(
        find.text('ID pasien aktif: ${AppConfig.defaultPatientId}'),
        findsOneWidget,
      );

      await fillRequiredFields(tester);

      final TextFormField dateField = tester.widget<TextFormField>(
        find.byKey(const Key('draft-followup-date')),
      );
      final String? displayedDate = dateField.controller?.text;
      expect(displayedDate, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));

      await submit(tester);
      await tester.pumpAndSettle();

      expect(find.text(_draft.planText), findsOneWidget);
      for (final String intensity in _draft.careIntensity) {
        expect(find.text(intensity), findsOneWidget);
      }
      expect(find.text('DRAFT pending human approval'), findsOneWidget);
      expect(find.byType(RiskBadge), findsOneWidget);
      expect(find.text('DRAF'), findsOneWidget);
      expect(find.text(_draft.disclaimer), findsOneWidget);
      expect(find.text('Lanjut ke meja persetujuan'), findsOneWidget);

      expect(sentPatientId, AppConfig.defaultPatientId);
      expect(sentHotline, '1500-HOME');
      expect(sentFollowupDate, displayedDate);
      expect(sentFollowupDate, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      expect(sentF1, same(_f1));

      expect(containerOf(tester).read(draftResultProvider), same(_draft));
    },
  );

  testWidgets('validates every field before calling the API', (tester) async {
    final FakeSyncareApi api = FakeSyncareApi();
    bool called = false;
    api.onDraftPlan =
        ({
          required String patientId,
          required String followupDate,
          required String hotline,
          required DischargeResult f1ScoredOutput,
        }) async {
          called = true;
          return _draft;
        };

    await pumpScreen(tester, api: api);

    await tester.enterText(find.byKey(const Key('draft-patient-id')), '   ');
    await submit(tester);
    await tester.pumpAndSettle();

    expect(find.text('ID pasien wajib diisi.'), findsOneWidget);
    expect(find.text('Pilih tanggal tindak lanjut.'), findsOneWidget);
    expect(find.text('Hotline wajib diisi.'), findsOneWidget);
    expect(called, isFalse);
    expect(find.byKey(const Key('draft-result')), findsNothing);
  });

  testWidgets('shows a loading state while the draft request is pending', (
    tester,
  ) async {
    final FakeSyncareApi api = FakeSyncareApi();
    final Completer<PlanDraft> pending = Completer<PlanDraft>();
    api.onDraftPlan =
        ({
          required String patientId,
          required String followupDate,
          required String hotline,
          required DischargeResult f1ScoredOutput,
        }) => pending.future;

    await pumpScreen(tester, api: api);
    await fillRequiredFields(tester);
    await submit(tester);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Menyusun draf tindak lanjut…'), findsOneWidget);
    expect(find.byKey(const Key('draft-result')), findsNothing);

    pending.complete(_draft);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('draft-result')), findsOneWidget);
    expect(find.text(_draft.planText), findsOneWidget);
    expect(containerOf(tester).read(draftResultProvider), same(_draft));
  });

  testWidgets('shows the mapped error and retries the draft request', (
    tester,
  ) async {
    final FakeSyncareApi api = FakeSyncareApi();
    api.onDraftPlan =
        ({
          required String patientId,
          required String followupDate,
          required String hotline,
          required DischargeResult f1ScoredOutput,
        }) async {
          throw const NetworkException();
        };

    await pumpScreen(tester, api: api);
    await fillRequiredFields(tester);
    await submit(tester);
    await tester.pumpAndSettle();

    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text('Tidak bisa menghubungi server'), findsOneWidget);
    expect(containerOf(tester).read(draftResultProvider), isNull);

    api.onDraftPlan =
        ({
          required String patientId,
          required String followupDate,
          required String hotline,
          required DischargeResult f1ScoredOutput,
        }) async => _draft;

    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('draft-result')), findsOneWidget);
    expect(containerOf(tester).read(draftResultProvider), same(_draft));
  });

  testWidgets('shows missing facts from the server as a warning', (
    tester,
  ) async {
    final FakeSyncareApi api = FakeSyncareApi();
    api.onDraftPlan =
        ({
          required String patientId,
          required String followupDate,
          required String hotline,
          required DischargeResult f1ScoredOutput,
        }) async => _incompleteDraft;

    await pumpScreen(tester, api: api);
    await fillRequiredFields(tester);
    await submit(tester);
    await tester.pumpAndSettle();

    expect(find.text('Fakta yang belum lengkap'), findsOneWidget);
    for (final String fact in _incompleteDraft.missingFacts) {
      expect(find.text(fact), findsOneWidget);
    }
    expect(
      containerOf(tester).read(draftResultProvider),
      same(_incompleteDraft),
    );
  });
}
