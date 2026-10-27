import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncare_flutter/core/api_exception.dart';
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
}
