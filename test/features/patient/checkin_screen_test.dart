import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncare_flutter/core/api_exception.dart';
import 'package:syncare_flutter/core/config.dart';
import 'package:syncare_flutter/core/providers.dart';
import 'package:syncare_flutter/features/patient/checkin_screen.dart';
import 'package:syncare_flutter/models/checkin_result.dart';
import 'package:syncare_flutter/widgets/disclaimer_banner.dart';
import 'package:syncare_flutter/widgets/risk_badge.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

CheckinResult _routineResult() {
  return const CheckinResult(
    action: 'routine',
    patientId: 'demo-1',
    baselineScore: 2,
    baselineTier: 'LOW',
    adjustments: <CheckinAdjustment>[
      CheckinAdjustment(condition: 'sesak napas', applied: true, points: 2),
      CheckinAdjustment(condition: 'demam', applied: false, points: 0),
    ],
    score: 5,
    tier: 'MEDIUM',
    tierChanged: true,
    nextCheckinDays: 3,
    label: 'demo-heuristic-v1',
    disclaimer: 'Bukan diagnosis medis. Selalu ikuti arahan tenaga kesehatan.',
    raw: <String, dynamic>{
      'action': 'routine',
      'patient_id': 'demo-1',
      'baseline_tier': 'LOW',
      'baseline_score': 2,
      'tier': 'MEDIUM',
      'tier_changed': true,
      'score': 5,
      'adjustments': <Map<String, dynamic>>[
        <String, dynamic>{
          'condition': 'sesak napas',
          'applied': true,
          'points': 2,
        },
        <String, dynamic>{'condition': 'demam', 'applied': false, 'points': 0},
      ],
      'next_checkin_days': 3,
      'label': 'demo-heuristic-v1',
      'disclaimer':
          'Bukan diagnosis medis. Selalu ikuti arahan tenaga kesehatan.',
    },
  );
}

Future<void> _pumpScreen(WidgetTester tester, FakeSyncareApi api) async {
  await tester.pumpWidget(
    wrapScreen(
      const PatientCheckinScreen(),
      overrides: <Override>[apiProvider.overrideWithValue(api)],
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _submitMessage(WidgetTester tester, String message) async {
  await tester.enterText(find.byType(TextField), message);
  await tester.pump();
  await tester.ensureVisible(find.text('Kirim check-in'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Kirim check-in'));
  await tester.pump();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'renders the app bar, disclaimer, patient caption, empty state, and form',
    (tester) async {
      final FakeSyncareApi api = FakeSyncareApi();
      await _pumpScreen(tester, api);

      expect(find.text('Check-in Pasien'), findsOneWidget);
      expect(find.byType(DisclaimerBanner), findsOneWidget);
      expect(
        find.text('ID pasien: ${AppConfig.defaultPatientId}'),
        findsOneWidget,
      );
      expect(find.text('Belum ada check-in'), findsOneWidget);
      expect(
        find.text(
          'Tulis kondisi Anda hari ini. Perubahan gejala akan diteruskan ke '
          'tim perawat.',
        ),
        findsOneWidget,
      );
      expect(find.text('Kirim check-in'), findsOneWidget);

      final TextField field = tester.widget<TextField>(find.byType(TextField));
      expect(field.minLines, 4);

      final double bannerTop = tester
          .getTopLeft(find.byType(DisclaimerBanner))
          .dy;
      final double emptyTop = tester
          .getTopLeft(find.text('Belum ada check-in'))
          .dy;
      expect(bannerTop, lessThan(emptyTop));
    },
  );

  testWidgets('rejects an empty check-in without calling the API', (
    tester,
  ) async {
    int calls = 0;
    final FakeSyncareApi api = FakeSyncareApi()
      ..onCheckin =
          ({required String patientId, required String message}) async {
            calls++;
            return _routineResult();
          };

    await _pumpScreen(tester, api);
    await tester.ensureVisible(find.text('Kirim check-in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kirim check-in'));
    await tester.pump();

    expect(calls, 0);
    expect(find.text('Tulis kondisi Anda terlebih dahulu.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('shows a spinner while the check-in request is pending', (
    tester,
  ) async {
    final Completer<CheckinResult> completer = Completer<CheckinResult>();
    final FakeSyncareApi api = FakeSyncareApi()
      ..onCheckin = ({required String patientId, required String message}) =>
          completer.future;

    await _pumpScreen(tester, api);
    await _submitMessage(tester, 'sesak napas sejak pagi');

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Mengirim check-in…'), findsOneWidget);

    completer.complete(_routineResult());
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(RiskBadge), findsOneWidget);
  });

  testWidgets('renders the escalation red flag above every other element', (
    tester,
  ) async {
    const String reason = 'sesak napas berat, nyeri dada';
    String? receivedMessage;
    String? receivedPatientId;

    final FakeSyncareApi api = FakeSyncareApi()
      ..onCheckin =
          ({required String patientId, required String message}) async {
            receivedPatientId = patientId;
            receivedMessage = message;
            return const CheckinResult(
              action: 'escalate_immediately',
              reason: reason,
              raw: <String, dynamic>{
                'action': 'escalate_immediately',
                'reason': 'sesak napas berat, nyeri dada',
              },
            );
          };

    await _pumpScreen(tester, api);
    await _submitMessage(tester, '  sesak napas berat, nyeri dada  ');
    await tester.pumpAndSettle();

    expect(receivedPatientId, AppConfig.defaultPatientId);
    expect(receivedMessage, 'sesak napas berat, nyeri dada');
    expect(find.text('PERLU TINDAKAN SEGERA'), findsOneWidget);
    expect(find.text(reason), findsOneWidget);
    expect(find.textContaining('melewati penilaian risiko'), findsOneWidget);
    expect(find.byType(RiskBadge), findsNothing);

    final Finder escalationCard = find.byKey(
      const Key('checkin-escalation-card'),
    );
    expect(escalationCard, findsOneWidget);
    final double cardTop = tester.getTopLeft(escalationCard).dy;
    final double rawTop = tester.getTopLeft(find.text('Respons API mentah')).dy;
    expect(cardTop, lessThan(rawTop));

    await tester.ensureVisible(find.text('Respons API mentah'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Respons API mentah'));
    await tester.pumpAndSettle();

    expect(find.textContaining('escalate_immediately'), findsWidgets);
  });

  testWidgets('maps EngineWarmingException to friendly copy and retries', (
    tester,
  ) async {
    int calls = 0;
    final FakeSyncareApi api = FakeSyncareApi()
      ..onCheckin =
          ({required String patientId, required String message}) async {
            calls++;
            if (calls == 1) {
              throw const EngineWarmingException();
            }
            return _routineResult();
          };

    await _pumpScreen(tester, api);
    await _submitMessage(tester, 'sesak napas sejak pagi');
    await tester.pumpAndSettle();

    expect(find.text('Layanan sedang menyiapkan, coba lagi'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);

    await tester.ensureVisible(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.byType(RiskBadge), findsOneWidget);
    expect(find.text('Tier berubah: LOW → MEDIUM'), findsOneWidget);
  });

  testWidgets('renders routine scoring verbatim and the raw API response', (
    tester,
  ) async {
    final CheckinResult result = _routineResult();
    final FakeSyncareApi api = FakeSyncareApi()
      ..onCheckin =
          ({required String patientId, required String message}) async =>
              result;

    await _pumpScreen(tester, api);
    await _submitMessage(tester, 'sesak napas sejak pagi');
    await tester.pumpAndSettle();

    expect(find.byType(RiskBadge), findsOneWidget);
    expect(find.text('MEDIUM'), findsOneWidget);
    expect(find.text('Tier berubah: LOW → MEDIUM'), findsOneWidget);
    expect(find.text('Skor risiko: 5'), findsOneWidget);
    expect(find.text('Check-in berikutnya dalam 3 hari'), findsOneWidget);
    expect(find.text('sesak napas'), findsOneWidget);
    expect(find.text('Diterapkan'), findsOneWidget);
    expect(find.text('2 poin'), findsOneWidget);
    expect(find.text('demam'), findsOneWidget);
    expect(find.text('Tidak diterapkan'), findsOneWidget);
    expect(find.text('0 poin'), findsOneWidget);
    expect(find.text(result.label), findsOneWidget);
    expect(find.text(result.disclaimer), findsOneWidget);
    expect(find.text('Respons API mentah'), findsOneWidget);

    await tester.ensureVisible(find.text('Respons API mentah'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Respons API mentah'));
    await tester.pumpAndSettle();

    final String raw = const JsonEncoder.withIndent('  ').convert(result.raw);
    expect(find.text(raw), findsOneWidget);
  });

  testWidgets('shows the current tier when it did not change', (tester) async {
    const CheckinResult result = CheckinResult(
      action: 'routine',
      score: 1,
      tier: 'LOW',
      label: 'demo-heuristic-v1',
      disclaimer: 'Bukan diagnosis medis.',
    );
    final FakeSyncareApi api = FakeSyncareApi()
      ..onCheckin =
          ({required String patientId, required String message}) async =>
              result;

    await _pumpScreen(tester, api);
    await _submitMessage(tester, 'lelah ringan');
    await tester.pumpAndSettle();

    expect(find.text('Tier saat ini: LOW'), findsOneWidget);
    expect(find.textContaining('Tier berubah'), findsNothing);
  });
}
