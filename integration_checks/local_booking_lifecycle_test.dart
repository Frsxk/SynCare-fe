import '../tool/private_fixture.dart';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncare_flutter/core/api_exception.dart';
import 'package:syncare_flutter/core/providers.dart';
import 'package:syncare_flutter/core/session_api.dart';
import 'package:syncare_flutter/core/theme.dart';
import 'package:syncare_flutter/features/auth/session_controller.dart';
import 'package:syncare_flutter/features/patient/homecare_providers.dart';
import 'package:syncare_flutter/features/patient/booking_detail_screen.dart';
import 'package:syncare_flutter/models/homecare.dart';
import 'package:syncare_flutter/models/session.dart';
import '../test/helpers/fakes.dart';

void main() {
  Booking? captured;
  test(
    'actual M06 own provider cancellation/history, public reason and logout/foreign denial',
    () async {
      final previous = HttpOverrides.current;
      HttpOverrides.global = null;
      addTearDown(() => HttpOverrides.global = previous);
      final accounts =
          (readPrivateFixture(
                File('../SynCare-be/data/local-demo-accounts.json'),
              ))['patients']
              as List;
      final dio = Dio(
        BaseOptions(
          baseUrl: 'http://127.0.0.1:8080',
          contentType: Headers.jsonContentType,
          followRedirects: false,
        ),
      );
      final scope = ProviderContainer(
        overrides: [
          sessionApiProvider.overrideWithValue(DioSessionApi(dio)),
          tokenSourceProvider.overrideWithValue(FakeTokenSource()),
          apiBaseUrlProvider.overrideWithValue('http://127.0.0.1:8080'),
        ],
      );
      addTearDown(() {
        scope.dispose();
        dio.close(force: true);
      });
      scope.read(sessionControllerProvider);
      await Future<void>.delayed(Duration.zero);
      final session = scope.read(sessionControllerProvider.notifier);
      try {
        await session.login(
          accounts[0]['identifier'] as String,
          accounts[0]['password'] as String,
        );
        final own =
            (scope.read(sessionControllerProvider) as SessionAuthenticated)
                .session
                .principal
                .patientId!;
        final api = scope.read(apiProvider),
            catalog = await api.listHomecareServices(),
            start = DateTime.fromMillisecondsSinceEpoch(
              DateTime.now().millisecondsSinceEpoch,
              isUtc: true,
            ).add(const Duration(days: 1));
        await scope
            .read(bookingSubmitProvider.notifier)
            .submit(
              BookingInput(
                serviceId: catalog.services.first.id,
                fullAddress: 'Alamat sintetis M06 Flutter cancellation',
                kelurahan: 'Kelurahan uji',
                kecamatan: 'Kecamatan uji',
                city: 'Jakarta Pusat',
                startAt: start.toIso8601String(),
                endAt: start.add(const Duration(hours: 1)).toIso8601String(),
                visitNote:
                    'DATA UJI M06: Flutter patient cancellation. Tanpa kunjungan nyata.',
              ),
            );
        expect(scope.read(bookingSubmitProvider), isA<BookingSaved>());
        final saved =
            (scope.read(bookingSubmitProvider) as BookingSaved).booking;
        final provider = bookingDetailProvider(saved.id),
            subscription = scope.listen(provider, (_, _) {});
        for (
          var i = 0;
          i < 50 && scope.read(provider) is BookingDetailLoading;
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        expect(scope.read(provider), isA<BookingReady>());
        await scope
            .read(provider.notifier)
            .cancel('Pembatalan sintetis dari Flutter M06.');
        final state = scope.read(provider) as BookingReady;
        expect(state.feedback, isA<CancelCommitted>());
        captured = state.booking;
        expect(captured!.status, BookingStatus.cancelled);
        expect(
          captured!.timeline.last.reason,
          'Pembatalan sintetis dari Flutter M06.',
        );
        expect(
          (await api.listBookings(own)).bookings.any(
            (b) => b.id == saved.id && b.status == BookingStatus.cancelled,
          ),
          true,
        );
        expect(
          (await api.getBooking(saved.id)).timeline.last.reason,
          captured!.timeline.last.reason,
        );
        File('../SynCare-be/data/m06-flutter-evidence.json').writeAsStringSync(
          jsonEncode({
            'id': saved.id,
            'patientId': own,
            'status': 'Cancelled',
            'verifiedAt': DateTime.now().toUtc().toIso8601String(),
          }),
        );
        await session.logout();
        expect(scope.read(provider), isA<BookingDetailFailure>());
        await session.login(
          accounts[1]['identifier'] as String,
          accounts[1]['password'] as String,
        );
        await expectLater(
          scope.read(apiProvider).getBooking(saved.id),
          throwsA(isA<NotFoundException>()),
        );
        subscription.close();
      } finally {
        await session.logout();
      }
    },
  );
  testWidgets(
    'exact real cancelled booking history/reason renders without invented schedule at320/text200',
    (tester) async {
      expect(captured, isNotNull);
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final reason = TextEditingController();
      addTearDown(reason.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsetsDirectional.all(24),
                child: BookingDetailContent(
                  state: BookingReady(captured!),
                  reason: reason,
                  onRefresh: () {},
                  onCancel: () {},
                  onReconcile: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Status: Dibatalkan'), findsOneWidget);
      expect(
        find.text('Alasan: Pembatalan sintetis dari Flutter M06.'),
        findsOneWidget,
      );
      expect(find.text('Batalkan pengajuan'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
