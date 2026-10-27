import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncare_flutter/core/api_exception.dart';
import 'package:syncare_flutter/features/patient/checkin_detail_screen.dart';
import 'package:syncare_flutter/features/patient/checkin_history_screen.dart';
import 'package:syncare_flutter/features/patient/checkin_providers.dart';
import 'package:syncare_flutter/models/checkin_record.dart';
import '../../helpers/fakes.dart';
import '../../helpers/checkin_fixture.dart';
import '../../helpers/pump_app.dart';

void main() {
  testWidgets(
    'history_reopen_persists: API records after reopen; empty, error and retained content have honest retry',
    (tester) async {
      final api = FakeSyncareApi()
        ..onListCheckins = (id, cursor) async =>
            CheckinPage([checkinFixture(state: 'UNKNOWN')], null);
      Future<void> open() async {
        await tester.pumpWidget(
          wrapScreen(
            const CheckinHistoryScreen(),
            overrides: [
              checkinHistoryProvider.overrideWith(
                (_) => CheckinHistoryController(api, 'patient-a')..load(),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();
      }

      await open();
      expect(find.textContaining('belum dapat dipastikan'), findsOneWidget);
      api.onListCheckins = (id, cursor) => throw const NetworkException();
      await tester.tap(find.text('Muat ulang riwayat'));
      await tester.pumpAndSettle();
      expect(find.textContaining('belum dapat dipastikan'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      api.onListCheckins = (id, cursor) async => const CheckinPage([], null);
      await open();
      expect(find.text('Belum ada laporan tersimpan.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
  testWidgets(
    'history and detail show the WIB created label at 320px/text200 without raw UTC',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final record = checkinFixture();

      await tester.pumpWidget(
        wrapScreen(
          SingleChildScrollView(child: CheckinHistoryRow(record: record)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Laporan 2026-10-25 07:00 WIB'), findsOneWidget);
      expect(find.textContaining('2026-10-25T00:00:00Z'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        wrapScreen(
          SingleChildScrollView(child: CheckinEvidence(record: record)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Waktu kirim: 2026-10-25 07:00 WIB'), findsOneWidget);
      expect(find.textContaining('2026-10-25T00:00:00Z'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
