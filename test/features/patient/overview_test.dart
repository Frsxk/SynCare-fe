import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncare_flutter/core/api_exception.dart';
import 'package:syncare_flutter/core/theme.dart';
import 'package:syncare_flutter/features/patient/home_screen.dart';
import 'package:syncare_flutter/features/patient/patient_providers.dart';
import 'package:syncare_flutter/models/patient.dart';
import '../../helpers/patient_fixture.dart';
import '../../helpers/checkin_fixture.dart';
import 'package:syncare_flutter/features/patient/checkin_providers.dart';

void main() {
  testWidgets(
    'confirmed LOW never suppresses a known urgent report and information-only guidance',
    (tester) async {
      final report = checkinJson(patientId: 'record-a', urgent: true);
      (report['baseline'] as Map)['score'] = 0;
      final json = overviewJson(status: 'confirmed')..['latestReport'] = report;
      final overview = PatientOverview.fromJson(json);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ownOverviewProvider.overrideWith((_) async => overview),
            emergencyGuidanceProvider.overrideWith(
              (_) async => guidanceFixture,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const PatientHomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('LOW'), findsOneWidget);
      expect(find.text('Kutipan mendesak dari F2 sintetis'), findsOneWidget);
      expect(
        find.textContaining('Aplikasi tidak melakukan panggilan'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  test(
    'overview rejects missing sources, mismatched current evidence and invalid category without clinical defaults',
    () {
      final valid = overviewJson(status: 'confirmed');
      expect(PatientOverview.fromJson(valid).confirmedRisk.current?.score, 0);
      final missing = overviewJson()..['activeBookingCounts'] = 0;
      expect(
        () => PatientOverview.fromJson(missing),
        throwsA(isA<InvalidResponseException>()),
      );
      final wrong = overviewJson(status: 'confirmed');
      (wrong['currentDischarge'] as Map<String, dynamic>)['id'] =
          'another-source';
      expect(
        () => PatientOverview.fromJson(wrong),
        throwsA(isA<InvalidResponseException>()),
      );
      final badCategory = overviewJson(status: 'confirmed');
      ((badCategory['confirmedRisk'] as Map<String, dynamic>)['current']
              as Map<String, dynamic>)['category'] =
          'UNKNOWN';
      expect(
        () => PatientOverview.fromJson(badCategory),
        throwsA(isA<InvalidResponseException>()),
      );
    },
  );
  testWidgets(
    'overview_missing_confirmation: 320dp text200 keeps labels and profile action scrollable without showing proposed HIGH',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ownOverviewProvider.overrideWith((ref) async => overviewFixture()),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const PatientHomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Belum ada kategori risiko'), findsOneWidget);
      expect(find.text('HIGH'), findsNothing);
      await tester.ensureVisible(find.text('Lihat profil saya'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Lihat profil saya'), findsOneWidget);
    },
  );
  testWidgets(
    'offline refresh retains profile; permission loss removes cached identity',
    (tester) async {
      Object? failure;
      final scope = ProviderContainer(
        overrides: [
          ownOverviewProvider.overrideWith((ref) async {
            if (failure != null) {
              throw failure;
            }
            return overviewFixture();
          }),
        ],
      );
      addTearDown(scope.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: scope,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const PatientHomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pasien sintetis record-a'), findsOneWidget);
      failure = const NetworkException();
      scope.invalidate(ownOverviewProvider);
      await tester.pumpAndSettle();
      expect(find.text('Pasien sintetis record-a'), findsOneWidget);
      failure = const ForbiddenException();
      scope.invalidate(ownOverviewProvider);
      await tester.pumpAndSettle();
      expect(find.text('Pasien sintetis record-a'), findsNothing);
    },
  );
  testWidgets('failed first load exposes a real retry that recovers', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ownOverviewProvider.overrideWith((ref) async {
            attempts++;
            if (attempts == 1) {
              throw const NetworkException();
            }
            return overviewFixture();
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const PatientHomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final retry = find.widgetWithText(FilledButton, 'Coba lagi');
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Pasien sintetis record-a'), findsOneWidget);
  });
}
