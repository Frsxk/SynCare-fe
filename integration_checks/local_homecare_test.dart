import '../tool/private_fixture.dart';
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
import 'package:syncare_flutter/features/patient/booking_request_screen.dart';
import 'package:syncare_flutter/models/homecare.dart';
import 'package:syncare_flutter/models/session.dart';
import '../test/helpers/fakes.dart';

void main() {
  Booking? captured;
  test(
    'actual Dio M05 catalog and generation-bound own request, logout isolation and foreign patient denial',
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
            catalog = await api.listHomecareServices();
        expect(catalog.services, isNotEmpty);
        final input = BookingInput(
          serviceId: catalog.services.first.id,
          fullAddress: 'Alamat sintetis Flutter M05',
          kelurahan: 'Kelurahan uji',
          kecamatan: 'Kecamatan uji',
          city: 'Jakarta Pusat',
          startAt: '2030-01-02T01:00:00.000Z',
          endAt: '2030-01-02T02:00:00.000Z',
          visitNote: 'Pengujian Flutter, bukan kunjungan nyata.',
        );
        final controller = scope.read(bookingSubmitProvider.notifier);
        await controller.submit(input);
        expect(scope.read(bookingSubmitProvider), isA<BookingSaved>());
        captured = (scope.read(bookingSubmitProvider) as BookingSaved).booking;
        expect(captured!.patientId, own);
        expect(captured!.status, BookingStatus.requested);
        expect(captured!.hasConfirmedSlot, false);
        await session.logout();
        await session.login(
          accounts[1]['identifier'] as String,
          accounts[1]['password'] as String,
        );
        expect(scope.read(bookingSubmitProvider), isA<BookingDraft>());
        await expectLater(
          scope
              .read(apiProvider)
              .requestBooking(
                patientId: own,
                input: input,
                requestKey: 'e41921f4-b676-4d5d-a982-5ba3c05400fe',
              ),
          throwsA(isA<NotFoundException>()),
        );
      } finally {
        await session.logout();
      }
    },
  );
  testWidgets(
    'exact actual committed homecare receipt renders preference separately at320/text200',
    (tester) async {
      expect(captured, isNotNull);
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: BookingReceipt(booking: captured!),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pengajuan tersimpan'), findsOneWidget);
      expect(find.text('Status: Diajukan'), findsOneWidget);
      expect(
        find.textContaining('Belum ada jadwal atau petugas terkonfirmasi'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
