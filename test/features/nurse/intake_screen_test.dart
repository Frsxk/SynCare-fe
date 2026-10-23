import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncare_flutter/core/api_exception.dart';
import 'package:syncare_flutter/core/providers.dart';
import 'package:syncare_flutter/core/theme.dart';
import 'package:syncare_flutter/features/nurse/intake_screen.dart';
import 'package:syncare_flutter/models/discharge_result.dart';
import 'package:syncare_flutter/widgets/disclaimer_banner.dart';
import 'package:syncare_flutter/widgets/empty_state.dart';
import 'package:syncare_flutter/widgets/error_state.dart';
import 'package:syncare_flutter/widgets/risk_badge.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

const String _disclaimer =
    'Ini adalah keluaran demo sintetis dari heuristik demo dan bukan alat '
    'klinis. Jangan gunakan untuk keputusan medis.';

const String _summary =
    'Pasien CHF NYHA III, pulang 2026-10-01, furosemide 40mg harian, '
    'eGFR 52, rawat inap 6 hari melalui IGD.';

/// Mirrors the verified F1 output shape from the backend contract.
Map<String, dynamic> _payload() {
  return <String, dynamic>{
    'episode': <String, dynamic>{
      'diagnosis': 'CHF NYHA III',
      'medications': <String>['furosemide 40mg harian'],
      'instructions': <String>['timbang berat badan harian'],
      'followup_needs': <String>['kontrol kardiologi 7 hari'],
      'length_of_stay_days': 6,
      'admission_type': 'emergency',
      'comorbidity_count': 4,
    },
    'score': 4,
    'tier': 'HIGH',
    'risk_factors': <String, dynamic>{
      'length_of_stay_days': <String, dynamic>{
        'value': 6,
        'threshold': 5,
        'points': 2,
        'met': true,
      },
      'admission_type': <String, dynamic>{
        'value': 'emergency',
        'threshold': 'emergency',
        'points': 1,
        'met': true,
      },
      'comorbidity_count': <String, dynamic>{
        'value': 4,
        'threshold': 3,
        'points': 1,
        'met': false,
      },
    },
    'rationale':
        'Rawat inap lama, admisi darurat, dan komorbiditas tinggi menaikkan '
        'risiko.',
    'label': 'demo-heuristic-v1',
    'missing_fields': <String>['admissions_prior_12m'],
    'not_clinically_validated': true,
    'synthetic_demo_only': true,
    'disclaimer': _disclaimer,
  };
}

DischargeResult _result() => DischargeResult.fromJson(_payload());

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpIntake(WidgetTester tester, FakeSyncareApi fake) async {
    await tester.pumpWidget(
      wrapScreen(
        const NurseIntakeScreen(),
        overrides: <Override>[apiProvider.overrideWithValue(fake)],
      ),
    );
    await tester.pump();
  }

  Future<void> enterAndSubmit(WidgetTester tester, String summary) async {
    await tester.enterText(find.byType(TextField), summary);
    await tester.pump();

    final Finder submitButton = find.text('Nilai ringkasan pulang');
    await tester.ensureVisible(submitButton);
    await tester.pump();
    await tester.tap(submitButton);
    await tester.pump();
  }

  testWidgets('renders the form, disclaimer banner, and initial empty state', (
    tester,
  ) async {
    await pumpIntake(tester, FakeSyncareApi());

    expect(find.text('Intake Perawat'), findsOneWidget);
    expect(find.byType(DisclaimerBanner), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Nilai ringkasan pulang'), findsOneWidget);
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Belum ada penilaian'), findsOneWidget);
    expect(
      find.textContaining('F1 mengekstrak episode rawat inap'),
      findsOneWidget,
    );

    final TextField field = tester.widget<TextField>(find.byType(TextField));
    expect(field.minLines, greaterThanOrEqualTo(6));

    final double bannerTop = tester
        .getTopLeft(find.byType(DisclaimerBanner))
        .dy;
    final double fieldTop = tester.getTopLeft(find.byType(TextField)).dy;
    expect(bannerTop, lessThan(fieldTop));
  });

  testWidgets('renders every risk factor and the unvalidated output verbatim', (
    tester,
  ) async {
    String? capturedSummary;
    final FakeSyncareApi fake = FakeSyncareApi()
      ..onDischarge = (String summary) async {
        capturedSummary = summary;
        return _result();
      };

    await pumpIntake(tester, fake);
    await enterAndSubmit(tester, _summary);
    await tester.pumpAndSettle();

    expect(capturedSummary, _summary);

    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(NurseIntakeScreen)),
      listen: false,
    );
    expect(container.read(f1ResultProvider), isNotNull);

    expect(find.byType(RiskBadge), findsOneWidget);
    expect(find.text('HIGH'), findsOneWidget);
    expect(find.text('Penilaian risiko F1'), findsOneWidget);
    expect(find.text('demo-heuristic-v1'), findsOneWidget);
    expect(find.textContaining('Rawat inap lama'), findsOneWidget);

    expect(find.text('Length of stay days'), findsOneWidget);
    expect(find.text('Admission type'), findsOneWidget);
    expect(find.text('Comorbidity count'), findsOneWidget);

    expect(find.text('6'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('emergency'), findsNWidgets(2));
    expect(find.text('4'), findsNWidgets(2));
    expect(find.text('3'), findsOneWidget);
    expect(find.text('1'), findsNWidgets(2));
    expect(find.text('ya'), findsNWidgets(2));
    expect(find.text('tidak'), findsOneWidget);

    expect(find.text('admissions_prior_12m'), findsOneWidget);

    expect(find.text('Tidak tervalidasi klinis'), findsOneWidget);
    expect(find.text('not_clinically_validated'), findsOneWidget);
    expect(find.text('true'), findsOneWidget);
    expect(find.text(_disclaimer), findsOneWidget);

    expect(find.text('Lanjut ke draf'), findsOneWidget);
  });

  testWidgets('opens the draft route from the result', (tester) async {
    final FakeSyncareApi fake = FakeSyncareApi()
      ..onDischarge = (String summary) async => _result();
    final GoRouter router = GoRouter(
      initialLocation: '/nurse/intake',
      routes: <RouteBase>[
        GoRoute(
          path: '/nurse/intake',
          builder: (BuildContext context, GoRouterState state) =>
              const NurseIntakeScreen(),
        ),
        GoRoute(
          path: '/nurse/draft',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('Draft tujuan')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[apiProvider.overrideWithValue(fake)],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();

    await enterAndSubmit(tester, _summary);
    await tester.pumpAndSettle();

    final Finder continueButton = find.text('Lanjut ke draf');
    await tester.ensureVisible(continueButton);
    await tester.pump();
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    expect(find.text('Draft tujuan'), findsOneWidget);
  });

  testWidgets('shows a loading state while the F1 request is pending', (
    tester,
  ) async {
    final Completer<DischargeResult> completer = Completer<DischargeResult>();
    final FakeSyncareApi fake = FakeSyncareApi()
      ..onDischarge = (String summary) => completer.future;

    await pumpIntake(tester, fake);
    await enterAndSubmit(tester, _summary);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Menilai ringkasan pulang…'), findsOneWidget);
    expect(find.byType(EmptyState), findsNothing);

    completer.complete(_result());
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(RiskBadge), findsOneWidget);
  });

  testWidgets('shows the engine-warming error and retries the same summary', (
    tester,
  ) async {
    int calls = 0;
    final FakeSyncareApi fake = FakeSyncareApi()
      ..onDischarge = (String summary) async {
        calls += 1;
        if (calls == 1) {
          throw const EngineWarmingException();
        }
        return _result();
      };

    await pumpIntake(tester, fake);
    await enterAndSubmit(tester, _summary);
    await tester.pumpAndSettle();

    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text('Layanan sedang menyiapkan, coba lagi'), findsOneWidget);
    expect(find.textContaining('Mesin pemrosesan belum siap'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);
    expect(find.byType(EmptyState), findsNothing);
    expect(find.textContaining('EngineWarmingException'), findsNothing);

    final Finder retryButton = find.text('Coba lagi');
    await tester.ensureVisible(retryButton);
    await tester.pump();
    await tester.tap(retryButton);
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.byType(ErrorState), findsNothing);
    expect(find.byType(RiskBadge), findsOneWidget);
  });
}
