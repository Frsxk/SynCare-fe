import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncare_flutter/core/api_exception.dart';
import 'package:syncare_flutter/features/patient/checkin_screen.dart';
import 'package:syncare_flutter/features/patient/checkin_providers.dart';
import 'package:syncare_flutter/models/checkin_record.dart';
import '../../helpers/error_fixture.dart';
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
  testWidgets(
    'nested outcome_unknown keeps the exact body/key and recovers through reconcile',
    (tester) async {
      var calls = 0;
      final keys = <String>[], messages = <String>[];
      final api = FakeSyncareApi()
        ..onSubmitCheckin = (id, message, key) async {
          calls++;
          keys.add(key);
          messages.add(message);
          if (calls == 1) {
            throw apiExceptionForStatus(
              502,
              nestedErrorBody(
                'outcome_unknown',
                message: 'Hasil permintaan belum dapat dipastikan.',
                retryable: false,
              ),
            );
          }
          return checkinFixture(patientId: id);
        };
      final controller = CheckinSubmitController(api, 'patient-a');
      await tester.pumpWidget(
        wrapScreen(
          const PatientCheckinScreen(),
          overrides: [checkinSubmitProvider.overrideWith((_) => controller)],
        ),
      );
      await tester.enterText(find.byType(TextField), 'original body');
      await tester.ensureVisible(find.text('Kirim check-in'));
      await tester.tap(find.text('Kirim check-in'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('Status belum pasti'), findsOneWidget);
      expect(find.text('Periksa kiriman yang sama'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 20));
      expect(calls, 1);
      await tester.ensureVisible(find.text('Periksa kiriman yang sama'));
      await tester.tap(find.text('Periksa kiriman yang sama'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('Laporan tersimpan'), findsOneWidget);
      expect(keys[1], keys[0]);
      expect(messages, <String>['original body', 'original body']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'nested validation_failed keeps the draft editable and resubmits a corrected body with a new key',
    (tester) async {
      var calls = 0;
      final keys = <String>[], messages = <String>[];
      final api = FakeSyncareApi()
        ..onSubmitCheckin = (id, message, key) async {
          calls++;
          keys.add(key);
          messages.add(message);
          if (calls == 1) {
            throw apiExceptionForStatus(
              422,
              nestedErrorBody(
                'validation_failed',
                message: 'followup_date wajib diisi.',
              ),
            );
          }
          return checkinFixture(patientId: id);
        };
      final controller = CheckinSubmitController(api, 'patient-a');
      Future<void> pumpCheckin() async {
        await tester.pumpWidget(
          wrapScreen(
            const PatientCheckinScreen(),
            overrides: [checkinSubmitProvider.overrideWith((_) => controller)],
          ),
        );
        await tester.pumpAndSettle();
      }

      await pumpCheckin();
      await tester.enterText(find.byType(TextField), 'original body');
      await tester.ensureVisible(find.text('Kirim check-in'));
      await tester.tap(find.text('Kirim check-in'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('Status belum pasti'), findsNothing);
      expect(
        find.textContaining('Status kiriman belum pasti'),
        findsNothing,
      );
      expect(find.text('Periksa kiriman yang sama'), findsNothing);
      expect(
        find.text(
          'Laporan belum terkirim. Periksa kembali isi laporan, lalu kirim ulang.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('followup_date'), findsNothing);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.readOnly, isFalse);
      expect(field.controller!.text, 'original body');
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Kirim check-in'),
            )
            .onPressed,
        isNotNull,
      );

      await tester.enterText(find.byType(TextField), 'corrected body');
      await tester.ensureVisible(find.text('Kirim check-in'));
      await tester.tap(find.text('Kirim check-in'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(messages, <String>['original body', 'corrected body']);
      expect(keys[1], isNot(keys[0]));
      expect(find.text('Laporan tersimpan'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
