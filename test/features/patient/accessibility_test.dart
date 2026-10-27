import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncare_flutter/core/api_exception.dart';
import 'package:syncare_flutter/features/patient/checkin_screen.dart';
import 'package:syncare_flutter/features/patient/checkin_providers.dart';
import 'package:syncare_flutter/features/patient/checkin_detail_screen.dart';
import 'package:syncare_flutter/features/patient/qa_outcome_panel.dart';
import 'package:syncare_flutter/features/patient/home_screen.dart';
import 'package:syncare_flutter/features/patient/patient_providers.dart';
import 'package:syncare_flutter/models/ask_answer.dart';
import 'package:syncare_flutter/models/checkin_record.dart';
import 'package:syncare_flutter/widgets/risk_badge.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/fakes.dart';
import '../../helpers/checkin_fixture.dart';
import '../../helpers/patient_fixture.dart';

void largeNarrow(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 800);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

void main() {
  testWidgets(
    'AT16_heldrequeststateannouncement__320dp200_wrap__keyboardprimaryactions_usable',
    (tester) async {
      largeNarrow(tester);
      final pending = Completer<CheckinRecord>();
      var calls = 0;
      final api = FakeSyncareApi()
        ..onSubmitCheckin = (_, message, key) {
          calls++;
          return pending.future;
        };
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          wrapScreen(
            const PatientCheckinScreen(),
            overrides: [
              checkinSubmitProvider.overrideWith(
                (_) => CheckinSubmitController(api, 'patient-a'),
              ),
            ],
          ),
        );
        await tester.enterText(
          find.byType(TextField),
          'Data sintetis M11. Keluhan dan perubahan kondisi untuk uji aksesibilitas.',
        );
        final button = find.widgetWithText(FilledButton, 'Kirim check-in');
        await tester.ensureVisible(button);
        expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
        Focus.of(tester.element(find.text('Kirim check-in'))).requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump(const Duration(seconds: 1));
        expect(calls, 1);
        expect(find.text('Laporan tersimpan'), findsNothing);
        expect(find.text('Mengirim laporan...'), findsOneWidget);
        expect(
          tester
              .getSemantics(find.text('Mengirim laporan...'))
              .flagsCollection
              .isLiveRegion,
          isTrue,
        );
        expect(tester.widget<FilledButton>(button).onPressed, isNull);
        pending.complete(checkinFixture(state: 'PENDING'));
        await tester.pumpAndSettle();
        expect(find.text('Laporan tersimpan'), findsOneWidget);
        expect(find.textContaining('menunggu analisis'), findsOneWidget);
        expect(find.text('Analisis selesai.'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'AT16_allwarningsvisible__checkinredflag_and_QAurgent_noclaimdispatch at320 text200',
    (tester) async {
      largeNarrow(tester);
      final reason = List.filled(
        5,
        'Alasan mendesak sintetis dari server.',
      ).join(' ');
      for (final source in ['F2', 'F5']) {
        final record = checkinJson(urgent: true);
        (record['outcome'] as Map)['reason'] = reason;
        await tester.pumpWidget(
          wrapScreen(
            Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.all(24),
                child: source == 'F2'
                    ? CheckinEvidence(record: CheckinRecord.fromJson(record))
                    : QaOutcomePanel(
                        outcome: QuestionEmergency(reason, guidanceFixture),
                        onRetry: () {},
                      ),
              ),
            ),
            overrides: [
              emergencyGuidanceProvider.overrideWith(
                (_) async => guidanceFixture,
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Perlu pertolongan segera'), findsOneWidget);
        expect(find.text(reason), findsOneWidget);
        expect(
          find.textContaining('Aplikasi tidak melakukan panggilan'),
          findsOneWidget,
        );
        if (source == 'F5') {
          expect(
            find.textContaining('Pekerjaan pencatatan alert tersimpan'),
            findsNothing,
          );
          expect(
            find.textContaining('Aplikasi tidak mengirim bantuan'),
            findsOneWidget,
          );
        }
        await tester.scrollUntilVisible(
          find.textContaining('119'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets(
    'AT16_missing_confirmation never invents LOW; typed network failure has a working retry and preserves long text',
    (tester) async {
      largeNarrow(tester);
      var reads = 0;
      await tester.pumpWidget(
        wrapScreen(
          const PatientHomeScreen(),
          overrides: [
            ownOverviewProvider.overrideWith((_) async {
              reads++;
              if (reads == 1) throw const NetworkException();
              return overviewFixture();
            }),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RiskBadge), findsNothing);
      final retry = find.widgetWithText(FilledButton, 'Coba lagi');
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(reads, 2);
      expect(find.textContaining('Belum ada kategori risiko'), findsOneWidget);
      expect(find.text('LOW'), findsNothing);
      expect(find.text('HIGH'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
