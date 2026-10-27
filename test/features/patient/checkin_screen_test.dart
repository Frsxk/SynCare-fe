import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncare_flutter/features/patient/checkin_screen.dart';
import 'package:syncare_flutter/features/patient/checkin_providers.dart';
import 'package:syncare_flutter/models/checkin_record.dart';
import '../../helpers/fakes.dart';
import '../../helpers/checkin_fixture.dart';
import '../../helpers/pump_app.dart';

void main() {
  testWidgets(
    'checkin_saved_not_analyzed: delayed submit has no saved claim; doubletap one key; committed pending differs from analysis',
    (tester) async {
      final response = Completer<CheckinRecord>();
      var calls = 0;
      final api = FakeSyncareApi()
        ..onSubmitCheckin = (id, message, key) {
          calls++;
          return response.future;
        };
      final controller = CheckinSubmitController(api, 'patient-a');
      await tester.pumpWidget(
        wrapScreen(
          const PatientCheckinScreen(),
          overrides: [checkinSubmitProvider.overrideWith((_) => controller)],
        ),
      );
      await tester.enterText(find.byType(TextField), 'Synthetic report');
      await tester.ensureVisible(find.text('Kirim check-in'));
      await tester.tap(find.text('Kirim check-in'));
      await tester.pump();
      expect(find.text('Laporan tersimpan'), findsNothing);
      expect(find.text('Mengirim laporan...'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Kirim check-in'),
            )
            .onPressed,
        isNull,
      );
      response.complete(checkinFixture(state: 'PENDING'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('Laporan tersimpan'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.textContaining('menunggu analisis'), findsOneWidget);
      expect(find.text('Analisis selesai.'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
  testWidgets(
    'empty validates and 320px/text200 form/result controls remain scrollable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final api = FakeSyncareApi()
        ..onSubmitCheckin = (id, message, key) async => checkinFixture();
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
      await tester.ensureVisible(find.text('Kirim check-in'));
      await tester.tap(find.text('Kirim check-in'));
      await tester.pumpAndSettle();
      expect(find.text('Tulis kondisi Anda terlebih dahulu.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Synthetic unit report');
      await tester.ensureVisible(find.text('Kirim check-in'));
      await tester.tap(find.text('Kirim check-in'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Mulai laporan baru'));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Mulai laporan baru'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
