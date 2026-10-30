import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncare_flutter/app.dart';
import 'package:syncare_flutter/core/session_api.dart';
import 'package:syncare_flutter/features/auth/login_screen.dart';
import 'package:syncare_flutter/features/auth/session_controller.dart';
import 'package:syncare_flutter/models/session.dart';
import 'package:syncare_flutter/widgets/disclaimer_banner.dart';
import 'package:syncare_flutter/features/nurse/draft_screen.dart';
import 'package:syncare_flutter/features/nurse/intake_screen.dart';
import 'package:syncare_flutter/features/patient/alert_detail_screen.dart';
import 'package:syncare_flutter/features/patient/ask_screen.dart';
import 'package:syncare_flutter/features/patient/checkin_detail_screen.dart';
import 'package:syncare_flutter/features/patient/checkin_history_screen.dart';
import 'package:syncare_flutter/features/patient/home_screen.dart';
import 'package:syncare_flutter/features/patient/plan_screen.dart';

import 'features/auth/session_controller_test.dart' show FakeSessionApi, grant;
import 'helpers/fakes.dart';
import 'helpers/patient_fixture.dart';
import 'helpers/checkin_fixture.dart';
import 'package:syncare_flutter/models/checkin_record.dart';
import 'package:syncare_flutter/core/providers.dart' show apiProvider;
import 'package:syncare_flutter/models/homecare.dart';
import 'package:syncare_flutter/features/patient/homecare_providers.dart';
import 'helpers/homecare_fixture.dart';
import 'helpers/booking_lifecycle_fixture.dart';
import 'helpers/escalation_fixture.dart';
import 'package:syncare_flutter/models/escalation.dart';
import 'package:syncare_flutter/models/discharge_result.dart';
import 'package:syncare_flutter/models/verified_care_plan.dart';
import 'helpers/verified_plan_fixture.dart';

void main() {
  testWidgets(
    'M09 parity retains nurse Flutter routes behind validated role and removes them after logout',
    (tester) async {
      final scope = ProviderContainer(
        overrides: [
          sessionApiProvider.overrideWithValue(
            FakeSessionApi()
              ..onLogin = (id, _) async => SessionGrant(
                token: 'synthetic-nurse-token',
                session: SessionSnapshot(
                  principal: const SessionPrincipal(
                    id: 'nurse-a',
                    role: 'nurse',
                    capabilities: [],
                  ),
                  expiresAt: DateTime.now().toUtc().add(
                    const Duration(hours: 24),
                  ),
                ),
              ),
          ),
          tokenSourceProvider.overrideWithValue(FakeTokenSource()),
          apiProvider.overrideWithValue(FakeSyncareApi()),
        ],
      );
      addTearDown(scope.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: scope, child: const SynCareApp()),
      );
      await tester.pumpAndSettle();
      await scope
          .read(sessionControllerProvider.notifier)
          .login('nurse', 'fixture');
      await tester.pumpAndSettle();
      scope.read(routerProvider).go('/nurse/draft');
      await tester.pumpAndSettle();
      expect(find.byType(NurseDraftScreen), findsOneWidget);
      await scope.read(sessionControllerProvider.notifier).logout();
      await tester.pumpAndSettle();
      scope.read(routerProvider).go('/nurse/draft');
      await tester.pumpAndSettle();
      expect(find.byType(NurseDraftScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'M07 guarded patient router reads actual safe alert list/detail and logout removes access',
    (tester) async {
      final api = FakeSyncareApi();
      api.onListEscalations = (id, c) async => EscalationPage([
        escalationFixture(patientId: id, status: 'RESOLVED'),
      ], null);
      api.onGetEscalation = (_, _) async =>
          escalationFixture(patientId: 'record-a', status: 'RESOLVED');
      api.onGuidance = () async => guidanceFixture;
      final scope = ProviderContainer(
        overrides: [
          sessionApiProvider.overrideWithValue(
            FakeSessionApi()..onLogin = (id, _) async => grant(id),
          ),
          tokenSourceProvider.overrideWithValue(FakeTokenSource()),
          apiProvider.overrideWithValue(api),
        ],
      );
      addTearDown(scope.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: scope, child: const SynCareApp()),
      );
      await tester.pumpAndSettle();
      await scope
          .read(sessionControllerProvider.notifier)
          .login('a', 'synthetic-component-password');
      await tester.pumpAndSettle();
      scope.read(routerProvider).go('/patient/alerts');
      await tester.pumpAndSettle();
      final open = find.widgetWithText(
        OutlinedButton,
        'Buka detail tindak lanjut',
      );
      await tester.scrollUntilVisible(
        open,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(open);
      await tester.pumpAndSettle();
      expect(open.hitTestable(), findsOneWidget);
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(
        scope.read(routerProvider).state.uri.path,
        '/patient/alerts/alert-a',
      );
      expect(find.text('Status: Ditutup'), findsOneWidget);
      expect(
        find.textContaining('tidak menyatakan pasien sembuh'),
        findsOneWidget,
      );
      await scope.read(sessionControllerProvider.notifier).logout();
      await tester.pumpAndSettle();
      scope.read(routerProvider).go('/patient/alerts/alert-a');
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Status: Ditutup'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'M06 guarded router opens actual own booking list/detail/cancel and logout hides it',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      var cancelled = false;
      final api = FakeSyncareApi()
        ..onListBookings = (id, cursor) async => BookingPage([
          lifecycleFixture(
            patientId: id,
            status: cancelled ? 'Cancelled' : 'Requested',
          ),
        ], null);
      api.onGetBooking = (_) async => lifecycleFixture(
        patientId: 'record-a',
        status: cancelled ? 'Cancelled' : 'Requested',
      );
      api.onCancelBooking = (id, v, r, k) async {
        cancelled = true;
        return lifecycleFixture(patientId: 'record-a', status: 'Cancelled');
      };
      final scope = ProviderContainer(
        overrides: [
          sessionApiProvider.overrideWithValue(
            FakeSessionApi()..onLogin = (id, _) async => grant(id),
          ),
          tokenSourceProvider.overrideWithValue(FakeTokenSource()),
          apiProvider.overrideWithValue(api),
        ],
      );
      addTearDown(scope.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: scope, child: const SynCareApp()),
      );
      await tester.pumpAndSettle();
      await scope
          .read(sessionControllerProvider.notifier)
          .login('a', 'synthetic-component-password');
      await tester.pumpAndSettle();
      scope.read(routerProvider).go('/patient/bookings');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Buka detail booking'), 200);
      await tester.pumpAndSettle();
      final open = find.widgetWithText(OutlinedButton, 'Buka detail booking');
      await tester.ensureVisible(open);
      await tester.pumpAndSettle();
      expect(open.hitTestable(), findsOneWidget);
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(
        scope.read(routerProvider).state.uri.path,
        '/patient/bookings/booking-a',
      );
      final field = find.widgetWithText(TextField, 'Alasan pembatalan');
      await tester.ensureVisible(field);
      await tester.enterText(field, 'Pembatalan dari uji router');
      await tester.ensureVisible(find.text('Batalkan pengajuan'));
      await tester.tap(find.text('Batalkan pengajuan'));
      await tester.pumpAndSettle();
      expect(find.text('Status: Dibatalkan'), findsOneWidget);
      await tester.ensureVisible(find.text('Kembali ke booking saya'));
      await tester.tap(find.text('Kembali ke booking saya'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Status: Dibatalkan'), 200);
      expect(find.text('Status: Dibatalkan'), findsOneWidget);
      await scope.read(sessionControllerProvider.notifier).logout();
      await tester.pumpAndSettle();
      scope.read(routerProvider).go('/patient/bookings/booking-a');
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Status: Dibatalkan'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'M05 real guarded router opens catalog/form/committed receipt; logout removes booking access',
    (tester) async {
      final api = FakeSyncareApi()
        ..onHomecareServices = (_) async =>
            const ServicePage([demoService], null);
      api.onRequestBooking = (id, input, key) async =>
          bookingFixture(patientId: id);
      final scope = ProviderContainer(
        overrides: [
          sessionApiProvider.overrideWithValue(
            FakeSessionApi()..onLogin = (id, _) async => grant(id),
          ),
          tokenSourceProvider.overrideWithValue(FakeTokenSource()),
          apiProvider.overrideWithValue(api),
        ],
      );
      addTearDown(scope.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: scope, child: const SynCareApp()),
      );
      await tester.pumpAndSettle();
      await scope
          .read(sessionControllerProvider.notifier)
          .login('a', 'synthetic-component-password');
      await tester.pumpAndSettle();
      scope.read(routerProvider).go('/patient/homecare');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Ajukan kunjungan'));
      await tester.tap(find.text('Ajukan kunjungan'));
      await tester.pumpAndSettle();
      expect(find.text('Kirim pengajuan'), findsOneWidget);
      await scope.read(bookingSubmitProvider.notifier).submit(bookingInput);
      await tester.pumpAndSettle();
      expect(find.text('Pengajuan tersimpan'), findsOneWidget);
      await tester.ensureVisible(find.text('Buat pengajuan baru'));
      await tester.tap(find.text('Buat pengajuan baru'));
      await tester.pumpAndSettle();
      expect(find.text('Ajukan kunjungan'), findsOneWidget);
      expect(find.text('Pengajuan tersimpan'), findsNothing);
      await scope.read(sessionControllerProvider.notifier).logout();
      await tester.pumpAndSettle();
      scope.read(routerProvider).go('/patient/homecare');
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Pengajuan tersimpan'), findsNothing);
    },
  );
  testWidgets(
    'M04 real router opens compose, committed receipt, history and detail for own account at large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final api = FakeSyncareApi()
        ..onGetPatientOverview = (id) async => overviewFixture(id: id);
      api.onSubmitCheckin = (id, message, key) async =>
          checkinFixture(patientId: id);
      api.onListCheckins = (id, cursor) async =>
          CheckinPage([checkinFixture(patientId: id)], null);
      api.onGetCheckin = (id) async =>
          checkinFixture(id: id, patientId: 'record-a');
      final scope = ProviderContainer(
        overrides: [
          sessionApiProvider.overrideWithValue(
            FakeSessionApi()..onLogin = (id, _) async => grant(id),
          ),
          tokenSourceProvider.overrideWithValue(FakeTokenSource()),
          apiProvider.overrideWithValue(api),
        ],
      );
      addTearDown(scope.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: scope, child: const SynCareApp()),
      );
      await tester.pumpAndSettle();
      await scope
          .read(sessionControllerProvider.notifier)
          .login('a', 'synthetic-component-password');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Tulis check-in'));
      await tester.tap(find.text('Tulis check-in'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Synthetic own report');
      await tester.ensureVisible(find.text('Kirim check-in'));
      await tester.tap(find.text('Kirim check-in'));
      await tester.pumpAndSettle();
      expect(find.text('Laporan tersimpan'), findsOneWidget);
      await tester.ensureVisible(find.text('Buka riwayat laporan'));
      await tester.tap(find.text('Buka riwayat laporan'));
      await tester.pumpAndSettle();
      expect(find.text('Riwayat laporan saya'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Laporan 2026-10-25 07:00 WIB'),
        200,
      );
      await tester.tap(find.text('Laporan 2026-10-25 07:00 WIB'));
      await tester.pumpAndSettle();
      expect(find.text('Detail laporan'), findsOneWidget);
      expect(find.text('ID laporan: report-a'), findsNothing);
      expect(find.text('Rincian laporan'), findsNothing);
      expect(
        find.text('Waktu kirim: 2026-10-25 07:00 WIB'),
        findsOneWidget,
      );
      expect(find.textContaining('2026-10-25T00:00:00Z'), findsNothing);
      expect(find.text('Data sintetis khusus unit test.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await scope.read(sessionControllerProvider.notifier).logout();
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'anonymous entry shows login and cannot deep-link into patient data or nurse routes',
    (tester) async {
      final scope = ProviderContainer(
        overrides: [
          sessionApiProvider.overrideWithValue(FakeSessionApi()),
          tokenSourceProvider.overrideWithValue(FakeTokenSource()),
        ],
      );
      addTearDown(scope.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: scope, child: const SynCareApp()),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(DisclaimerBanner), findsOneWidget);
      expect(find.text('Saya Pasien'), findsNothing);
      scope.read(routerProvider).go('/patient/plan');
      await tester.pumpAndSettle();
      expect(scope.read(routerProvider).state.uri.path, '/');
      expect(find.text('Rencana Saya'), findsNothing);
    },
  );

  testWidgets(
    'login uses server identity, blocks nurse deep link and logout disposes old account content',
    (tester) async {
      final api = FakeSessionApi()..onLogin = (id, _) async => grant(id);
      final storage = FakeTokenSource();
      final scope = ProviderContainer(
        overrides: [
          sessionApiProvider.overrideWithValue(api),
          tokenSourceProvider.overrideWithValue(storage),
          apiProvider.overrideWithValue(
            FakeSyncareApi()
              ..onGetPatientOverview = (id) async => overviewFixture(id: id),
          ),
        ],
      );
      addTearDown(scope.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: scope, child: const SynCareApp()),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Identitas akun'),
        'a',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Kata sandi'),
        'synthetic-password',
      );
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Masuk'));
      await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
      await tester.pumpAndSettle();
      expect(find.text('Ringkasan saya'), findsOneWidget);
      expect(
        (scope.read(sessionControllerProvider) as SessionAuthenticated)
            .session
            .principal
            .patientId,
        'record-a',
      );
      scope.read(routerProvider).go('/nurse/approval');
      await tester.pumpAndSettle();
      expect(scope.read(routerProvider).state.uri.path, '/account');
      await tester.tap(find.text('Keluar'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('ID pasien: record-a'), findsNothing);
      expect(storage.token, isNull);
      expect(api.revoked, contains('synthetic-session-a'));
    },
  );

  testWidgets(
    'offline restore displays a retry state without rendering cached patient identity',
    (tester) async {
      final api = FakeSessionApi()
        ..onRestore = (_) async =>
            throw const SessionException(SessionFailure.unavailable);
      final scope = ProviderContainer(
        overrides: [
          sessionApiProvider.overrideWithValue(api),
          tokenSourceProvider.overrideWithValue(FakeTokenSource('saved-token')),
          apiProvider.overrideWithValue(
            FakeSyncareApi()
              ..onGetPatientOverview = (id) async => overviewFixture(id: id),
          ),
        ],
      );
      addTearDown(scope.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: scope, child: const SynCareApp()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sesi belum terverifikasi'), findsOneWidget);
      expect(find.byType(SessionAccountScreen), findsNothing);
      api.onRestore = (_) async => grant('b').session;
      await tester.tap(find.text('Periksa sesi lagi'));
      await tester.pumpAndSettle();
      expect(find.text('Ringkasan saya'), findsOneWidget);
      expect(
        (scope.read(sessionControllerProvider) as SessionAuthenticated)
            .session
            .principal
            .patientId,
        'record-b',
      );
      expect(
        scope.read(sessionControllerProvider),
        isA<SessionAuthenticated>(),
      );
      await scope.read(sessionControllerProvider.notifier).logout();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'M03 account entry opens own overview/profile through the real router and shell at 320px/text200',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final api = FakeSessionApi()..onLogin = (id, _) async => grant(id);
      final patientApi = FakeSyncareApi()
        ..onGetPatientOverview = (id) async => overviewFixture(id: id);
      final scope = ProviderContainer(
        overrides: [
          sessionApiProvider.overrideWithValue(api),
          tokenSourceProvider.overrideWithValue(FakeTokenSource()),
          apiProvider.overrideWithValue(patientApi),
        ],
      );
      addTearDown(scope.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: scope, child: const SynCareApp()),
      );
      await tester.pumpAndSettle();
      await scope
          .read(sessionControllerProvider.notifier)
          .login('a', 'synthetic-component-password');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Akun'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Ringkasan perawatan saya'));
      await tester.tap(find.text('Ringkasan perawatan saya'));
      await tester.pumpAndSettle();
      expect(find.text('Ringkasan saya'), findsOneWidget);
      expect(find.text('Pasien sintetis record-a'), findsOneWidget);
      expect(find.text('ID pasien: record-a'), findsNothing);
      await tester.ensureVisible(find.text('Lihat profil saya'));
      await tester.tap(find.text('Lihat profil saya'));
      await tester.pumpAndSettle();
      expect(find.text('Profil saya'), findsOneWidget);
      expect(find.text('ID pasien: record-a'), findsNothing);
      expect(find.text('Pasien sintetis record-a'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await scope.read(sessionControllerProvider.notifier).logout();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'system Back pops patient report detail then history one level and exits at home',
    (tester) async {
      final api = FakeSyncareApi();
      api.onGetPatientOverview = (id) async => overviewFixture(id: id);
      api.onListCheckins = (id, cursor) async => CheckinPage([
        checkinFixture(id: 'report-a', patientId: id),
      ], null);
      api.onGetCheckin = (id) async =>
          checkinFixture(id: id, patientId: 'record-a');
      final scope = ProviderContainer(
        overrides: [
          sessionApiProvider.overrideWithValue(
            FakeSessionApi()..onLogin = (id, _) async => grant(id),
          ),
          tokenSourceProvider.overrideWithValue(FakeTokenSource()),
          apiProvider.overrideWithValue(api),
        ],
      );
      addTearDown(scope.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: scope, child: const SynCareApp()),
      );
      await tester.pumpAndSettle();
      await scope
          .read(sessionControllerProvider.notifier)
          .login('a', 'synthetic-component-password');
      await tester.pumpAndSettle();
      expect(scope.read(routerProvider).state.uri.path, '/patient/home');
      await tester.ensureVisible(find.text('Buka riwayat laporan'));
      await tester.tap(find.text('Buka riwayat laporan'));
      await tester.pumpAndSettle();
      expect(scope.read(routerProvider).state.uri.path, '/patient/checkins');
      expect(find.byType(CheckinHistoryScreen), findsOneWidget);
      final report = find.text('Laporan 2026-10-25 07:00 WIB');
      await tester.scrollUntilVisible(
        report,
        200,
        scrollable: find
            .descendant(
              of: find.byType(CheckinHistoryScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(report);
      await tester.pumpAndSettle();
      expect(
        scope.read(routerProvider).state.uri.path,
        '/patient/checkins/report-a',
      );
      expect(find.byType(CheckinDetailScreen), findsOneWidget);
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(scope.read(routerProvider).state.uri.path, '/patient/checkins');
      expect(find.byType(CheckinDetailScreen), findsNothing);
      expect(find.byType(CheckinHistoryScreen), findsOneWidget);
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(scope.read(routerProvider).state.uri.path, '/patient/home');
      expect(find.byType(PatientHomeScreen), findsOneWidget);
      expect(find.byType(CheckinHistoryScreen), findsNothing);
      expect(await tester.binding.handlePopRoute(), isFalse);
      await tester.pumpAndSettle();
      expect(scope.read(routerProvider).state.uri.path, '/patient/home');
      expect(find.byType(PatientHomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await scope.read(sessionControllerProvider.notifier).logout();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'system Back at anonymous login is unhandled and keeps login visible',
    (tester) async {
      final scope = ProviderContainer(
        overrides: [
          sessionApiProvider.overrideWithValue(FakeSessionApi()),
          tokenSourceProvider.overrideWithValue(FakeTokenSource()),
        ],
      );
      addTearDown(scope.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: scope, child: const SynCareApp()),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(scope.read(routerProvider).state.uri.path, '/');
      expect(await tester.binding.handlePopRoute(), isFalse);
      await tester.pumpAndSettle();
      expect(scope.read(routerProvider).state.uri.path, '/');
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'shell tabs and account preserve the prior page, ignore repeated taps, and reset at home',
    (tester) async {
      final api = FakeSyncareApi();
      api.onGetPatientOverview = (id) async => overviewFixture(id: id);
      api.onListVerifiedPlans = (id, cursor) async =>
          VerifiedPlanPage([verifiedPlanFixture(patientId: id)], null);
      final scope = ProviderContainer(
        overrides: [
          sessionApiProvider.overrideWithValue(
            FakeSessionApi()..onLogin = (id, _) async => grant(id),
          ),
          tokenSourceProvider.overrideWithValue(FakeTokenSource()),
          apiProvider.overrideWithValue(api),
        ],
      );
      addTearDown(scope.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: scope, child: const SynCareApp()),
      );
      await tester.pumpAndSettle();
      await scope
          .read(sessionControllerProvider.notifier)
          .login('a', 'synthetic-component-password');
      await tester.pumpAndSettle();
      expect(scope.read(routerProvider).state.uri.path, '/patient/home');

      final tanyaTab = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Tanya'),
      );
      await tester.tap(tanyaTab);
      await tester.pumpAndSettle();
      expect(scope.read(routerProvider).state.uri.path, '/patient/ask');
      expect(find.byType(PatientAskScreen), findsOneWidget);
      await tester.tap(tanyaTab);
      await tester.pumpAndSettle();
      expect(scope.read(routerProvider).state.uri.path, '/patient/ask');
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(scope.read(routerProvider).state.uri.path, '/patient/home');
      expect(find.byType(PatientHomeScreen), findsOneWidget);

      final rencanaTab = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Rencana'),
      );
      await tester.tap(rencanaTab);
      await tester.pumpAndSettle();
      expect(scope.read(routerProvider).state.uri.path, '/patient/plan');
      expect(find.byType(PatientPlanScreen), findsOneWidget);
      await tester.tap(rencanaTab);
      await tester.pumpAndSettle();
      expect(scope.read(routerProvider).state.uri.path, '/patient/plan');

      final akunTab = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Akun'),
      );
      await tester.tap(akunTab);
      await tester.pumpAndSettle();
      expect(scope.read(routerProvider).state.uri.path, '/account');
      expect(find.byType(SessionAccountScreen), findsOneWidget);
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(scope.read(routerProvider).state.uri.path, '/patient/plan');
      expect(find.byType(PatientPlanScreen), findsOneWidget);
      expect(find.byType(SessionAccountScreen), findsNothing);

      await tester.tap(akunTab);
      await tester.pumpAndSettle();
      expect(scope.read(routerProvider).state.uri.path, '/account');
      await tester.ensureVisible(find.text('Ringkasan perawatan saya'));
      await tester.tap(find.text('Ringkasan perawatan saya'));
      await tester.pumpAndSettle();
      expect(scope.read(routerProvider).state.uri.path, '/patient/home');
      expect(find.byType(PatientHomeScreen), findsOneWidget);
      expect(await tester.binding.handlePopRoute(), isFalse);
      await tester.pumpAndSettle();
      expect(scope.read(routerProvider).state.uri.path, '/patient/home');
      expect(find.byType(PatientHomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await scope.read(sessionControllerProvider.notifier).logout();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'direct secondary deep link without history falls back to patient home on system Back',
    (tester) async {
      final api = FakeSyncareApi();
      api.onGetPatientOverview = (id) async => overviewFixture(id: id);
      api.onGetCheckin = (id) async =>
          checkinFixture(id: id, patientId: 'record-a');
      final scope = ProviderContainer(
        overrides: [
          sessionApiProvider.overrideWithValue(
            FakeSessionApi()..onLogin = (id, _) async => grant(id),
          ),
          tokenSourceProvider.overrideWithValue(FakeTokenSource()),
          apiProvider.overrideWithValue(api),
        ],
      );
      addTearDown(scope.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: scope, child: const SynCareApp()),
      );
      await tester.pumpAndSettle();
      await scope
          .read(sessionControllerProvider.notifier)
          .login('a', 'synthetic-component-password');
      await tester.pumpAndSettle();
      scope.read(routerProvider).go('/patient/checkins/report-a');
      await tester.pumpAndSettle();
      expect(
        scope.read(routerProvider).state.uri.path,
        '/patient/checkins/report-a',
      );
      expect(find.byType(CheckinDetailScreen), findsOneWidget);
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(scope.read(routerProvider).state.uri.path, '/patient/home');
      expect(find.byType(CheckinDetailScreen), findsNothing);
      expect(find.byType(PatientHomeScreen), findsOneWidget);
      expect(await tester.binding.handlePopRoute(), isFalse);
      await tester.pumpAndSettle();
      expect(scope.read(routerProvider).state.uri.path, '/patient/home');
      expect(tester.takeException(), isNull);
      await scope.read(sessionControllerProvider.notifier).logout();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'nurse account without history falls back to intake and pushed workflow Back pops',
    (tester) async {
      final scope = ProviderContainer(
        overrides: [
          sessionApiProvider.overrideWithValue(
            FakeSessionApi()
              ..onLogin = (id, _) async => SessionGrant(
                token: 'synthetic-nurse-token',
                session: SessionSnapshot(
                  principal: const SessionPrincipal(
                    id: 'nurse-a',
                    role: 'nurse',
                    capabilities: [],
                  ),
                  expiresAt: DateTime.now().toUtc().add(
                    const Duration(hours: 24),
                  ),
                ),
              ),
          ),
          tokenSourceProvider.overrideWithValue(FakeTokenSource()),
          apiProvider.overrideWithValue(
            FakeSyncareApi()
              ..onDischarge = (summary) async => const DischargeResult(
                tier: 'HIGH',
                score: 7,
                label: 'demo-heuristic-v1',
                disclaimer: 'Keluaran sintetis khusus pengujian.',
              ),
          ),
        ],
      );
      addTearDown(scope.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: scope, child: const SynCareApp()),
      );
      await tester.pumpAndSettle();
      await scope
          .read(sessionControllerProvider.notifier)
          .login('nurse', 'fixture');
      await tester.pumpAndSettle();
      expect(scope.read(routerProvider).state.uri.path, '/account');
      expect(find.byType(SessionAccountScreen), findsOneWidget);
      scope.read(routerProvider).go('/account');
      await tester.pumpAndSettle();
      expect(scope.read(routerProvider).state.uri.path, '/account');
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(scope.read(routerProvider).state.uri.path, '/nurse/intake');
      expect(find.byType(NurseIntakeScreen), findsOneWidget);

      await tester.enterText(
        find.byType(TextField),
        'Ringkasan pulang sintetis untuk pengujian navigasi.',
      );
      await tester.pump();
      await tester.ensureVisible(find.text('Nilai ringkasan pulang'));
      await tester.tap(find.text('Nilai ringkasan pulang'));
      await tester.pumpAndSettle();
      expect(find.text('Lanjut ke draf'), findsOneWidget);
      await tester.ensureVisible(find.text('Lanjut ke draf'));
      await tester.tap(find.text('Lanjut ke draf'));
      await tester.pumpAndSettle();
      expect(scope.read(routerProvider).state.uri.path, '/nurse/draft');
      expect(find.byType(NurseDraftScreen), findsOneWidget);
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(scope.read(routerProvider).state.uri.path, '/nurse/intake');
      expect(find.byType(NurseDraftScreen), findsNothing);
      expect(find.byType(NurseIntakeScreen), findsOneWidget);
      expect(await tester.binding.handlePopRoute(), isFalse);
      await tester.pumpAndSettle();
      expect(scope.read(routerProvider).state.uri.path, '/nurse/intake');
      expect(find.byType(NurseIntakeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await scope.read(sessionControllerProvider.notifier).logout();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'logout from a pushed detail/account stack leaves login and Back cannot revive protected pages',
    (tester) async {
      final api = FakeSyncareApi();
      api.onGetPatientOverview = (id) async => overviewFixture(id: id);
      api.onListCheckins = (id, cursor) async => CheckinPage([
        checkinFixture(id: 'report-a', patientId: id),
      ], null);
      api.onGetCheckin = (id) async =>
          checkinFixture(id: id, patientId: 'record-a');
      final scope = ProviderContainer(
        overrides: [
          sessionApiProvider.overrideWithValue(
            FakeSessionApi()..onLogin = (id, _) async => grant(id),
          ),
          tokenSourceProvider.overrideWithValue(FakeTokenSource()),
          apiProvider.overrideWithValue(api),
        ],
      );
      addTearDown(scope.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: scope, child: const SynCareApp()),
      );
      await tester.pumpAndSettle();
      await scope
          .read(sessionControllerProvider.notifier)
          .login('a', 'synthetic-component-password');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Buka riwayat laporan'));
      await tester.tap(find.text('Buka riwayat laporan'));
      await tester.pumpAndSettle();
      final report = find.text('Laporan 2026-10-25 07:00 WIB');
      await tester.scrollUntilVisible(
        report,
        200,
        scrollable: find
            .descendant(
              of: find.byType(CheckinHistoryScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(report);
      await tester.pumpAndSettle();
      expect(find.byType(CheckinDetailScreen), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Akun'),
        ),
      );
      await tester.pumpAndSettle();
      expect(scope.read(routerProvider).state.uri.path, '/account');
      expect(find.byType(SessionAccountScreen), findsOneWidget);
      await tester.tap(find.text('Keluar'));
      await tester.pumpAndSettle();
      expect(scope.read(routerProvider).state.uri.path, '/');
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(await tester.binding.handlePopRoute(), isFalse);
      await tester.pumpAndSettle();
      expect(scope.read(routerProvider).state.uri.path, '/');
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(SessionAccountScreen), findsNothing);
      expect(find.byType(CheckinDetailScreen), findsNothing);
      expect(find.byType(PatientHomeScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'system Back inside emergency confirmation dismisses only the dialog',
    (tester) async {
      var emergencyWrites = 0;
      final api = FakeSyncareApi();
      api.onGetPatientOverview = (id) async => overviewFixture(id: id);
      api.onListEscalations = (id, cursor) async =>
          EscalationPage([escalationFixture(patientId: id)], null);
      api.onRequestEmergency = (_, _, _) async {
        emergencyWrites++;
        throw UnimplementedError('Back must not confirm the dialog');
      };
      final scope = ProviderContainer(
        overrides: [
          sessionApiProvider.overrideWithValue(
            FakeSessionApi()..onLogin = (id, _) async => grant(id),
          ),
          tokenSourceProvider.overrideWithValue(FakeTokenSource()),
          apiProvider.overrideWithValue(api),
        ],
      );
      addTearDown(scope.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: scope, child: const SynCareApp()),
      );
      await tester.pumpAndSettle();
      await scope
          .read(sessionControllerProvider.notifier)
          .login('a', 'synthetic-component-password');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Buka status tindak lanjut'));
      await tester.tap(find.text('Buka status tindak lanjut'));
      await tester.pumpAndSettle();
      expect(scope.read(routerProvider).state.uri.path, '/patient/alerts');
      expect(find.byType(AlertHistoryScreen), findsOneWidget);
      final scrollable = find
          .descendant(
            of: find.byType(AlertHistoryScreen),
            matching: find.byType(Scrollable),
          )
          .first;
      final reason = find.byType(TextField);
      await tester.scrollUntilVisible(reason, 200, scrollable: scrollable);
      await tester.pumpAndSettle();
      await tester.enterText(reason, 'Sesak berat sintetis.');
      await tester.scrollUntilVisible(
        find.text('Minta bantuan segera'),
        200,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Minta bantuan segera'));
      await tester.tap(find.text('Minta bantuan segera'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Kirim permintaan ke perawat?'), findsOneWidget);
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(scope.read(routerProvider).state.uri.path, '/patient/alerts');
      expect(find.byType(AlertHistoryScreen), findsOneWidget);
      expect(emergencyWrites, 0);
      expect(tester.takeException(), isNull);
      await scope.read(sessionControllerProvider.notifier).logout();
      await tester.pumpAndSettle();
    },
  );
}
