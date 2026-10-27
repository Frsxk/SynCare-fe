import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncare_flutter/core/api_exception.dart';
import 'package:syncare_flutter/features/patient/homecare_providers.dart';
import 'package:syncare_flutter/features/patient/booking_request_screen.dart';
import 'package:syncare_flutter/features/patient/homecare_screen.dart';
import 'package:syncare_flutter/models/homecare.dart';
import '../../helpers/error_fixture.dart';
import '../../helpers/fakes.dart';
import '../../helpers/homecare_fixture.dart';
import '../../helpers/pump_app.dart';

void main() {
  test(
    'uncertain response retains exact intent; doubletap one key; no resurrection after dispose',
    () async {
      final pending = Completer<Booking>(),
          keys = <String>[],
          inputs = <BookingInput>[];
      final api = FakeSyncareApi()
        ..onRequestBooking = (id, input, key) {
          keys.add(key);
          inputs.add(input);
          return keys.length == 1
              ? pending.future
              : Future.value(bookingFixture());
        };
      final controller = BookingSubmitController(api, 'patient-a');
      final first = controller.submit(bookingInput);
      await controller.submit(bookingInput);
      expect(keys.length, 1);
      pending.completeError(const NetworkException());
      await first;
      expect(controller.state, isA<BookingUnknown>());
      await controller.reconcile();
      expect(controller.state, isA<BookingSaved>());
      expect(keys[0], keys[1]);
      expect(inputs[0], same(inputs[1]));
      controller.startNew();
      await controller.submit(bookingInput);
      expect(keys[2], isNot(keys[0]));
      controller.dispose();
      final late = Completer<Booking>();
      api.onRequestBooking = (id, input, key) => late.future;
      final disposed = BookingSubmitController(api, 'patient-a');
      final call = disposed.submit(bookingInput);
      disposed.dispose();
      late.complete(bookingFixture());
      await call;
    },
  );
  test(
    'typed outcome_unknown keeps the original BookingInput and key without auto resend',
    () async {
      final keys = <String>[], inputs = <BookingInput>[];
      var calls = 0;
      final api = FakeSyncareApi()
        ..onRequestBooking = (id, input, key) async {
          calls++;
          keys.add(key);
          inputs.add(input);
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
          return bookingFixture(patientId: id);
        };
      final controller = BookingSubmitController(api, 'patient-a');
      addTearDown(controller.dispose);
      await controller.submit(bookingInput);
      expect(calls, 1);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(calls, 1, reason: 'retryable must never auto-resend');
      expect(controller.state, isA<BookingUnknown>());
      expect(
        (controller.state as BookingUnknown).error,
        isA<OutcomeUnknownException>(),
      );
      await controller.submit(
        BookingInput(
          serviceId: bookingInput.serviceId,
          fullAddress: 'Alamat yang diedit',
          kelurahan: bookingInput.kelurahan,
          kecamatan: bookingInput.kecamatan,
          city: bookingInput.city,
          startAt: bookingInput.startAt,
          endAt: bookingInput.endAt,
        ),
      );
      expect(calls, 2);
      expect(keys[1], keys[0]);
      expect(inputs[1], same(inputs[0]));
    },
  );
  test(
    'definitive rejection permits correction, forbidden clears draft and foreign receipt fails closed',
    () async {
      final api = FakeSyncareApi()
        ..onRequestBooking = (id, input, key) =>
            throw const ValidationException('Data tidak valid.');
      final controller = BookingSubmitController(api, 'patient-a');
      addTearDown(controller.dispose);
      controller.draftFields['address'] = 'Address retained';
      await controller.submit(bookingInput);
      expect(controller.state, isA<BookingDraft>());
      expect(controller.draftFields['address'], 'Address retained');
      api.onRequestBooking = (id, input, key) async =>
          bookingFixture(patientId: 'foreign');
      await controller.submit(bookingInput);
      expect(controller.state, isA<BookingUnknown>());
      api.onRequestBooking = (id, input, key) =>
          throw const ForbiddenException();
      await controller.reconcile();
      expect(controller.state, isA<BookingUnavailable>());
      expect(controller.draftFields, isEmpty);
    },
  );
  test(
    'catalog refresh retains permitted data, pagination and denied access clears it',
    () async {
      final api = FakeSyncareApi()
        ..onHomecareServices = (cursor) async =>
            ServicePage([demoService], cursor == null ? 'next' : null);
      final controller = HomecareCatalog(api, 'patient-a');
      addTearDown(controller.dispose);
      await controller.load();
      await controller.load(next: true);
      expect(controller.state.valueOrNull?.services.length, 2);
      api.onHomecareServices = (_) => throw const NetworkException();
      await controller.load();
      expect(controller.state.valueOrNull?.services.length, 2);
      expect(controller.state.hasError, true);
      api.onHomecareServices = (_) => throw const ForbiddenException();
      await controller.load();
      expect(controller.state.valueOrNull, isNull);
    },
  );
  test(
    'booking contract rejects unknown status and fake confirmed schedule; date/window validation converts WIB to UTC',
    () {
      expect(
        () => Booking.fromJson(bookingJson(status: 'Unknown')),
        throwsA(isA<InvalidResponseException>()),
      );
      expect(
        () => Booking.fromJson({
          ...bookingJson(),
          'confirmedSlot': <String, dynamic>{},
        }),
        throwsA(isA<InvalidResponseException>()),
      );
      final fields = {
        'address': 'Address',
        'kelurahan': 'Village',
        'kecamatan': 'District',
        'city': 'Jakarta Pusat',
        'date': '2030-01-02',
        'start': '08:00',
        'end': '09:00',
      };
      expect(
        BookingInput.fromFields(demoService.id, fields).startAt,
        '2030-01-02T01:00:00.000Z',
      );
      for (final changed in [
        {'date': '2030-02-30'},
        {'end': '07:00'},
        {'start': '24:00'},
        {'address': ''},
      ]) {
        expect(
          () =>
              BookingInput.fromFields(demoService.id, {...fields, ...changed}),
          throwsA(isA<ValidationException>()),
        );
      }
    },
  );
  testWidgets(
    'booking_request_no_fake_schedule: uncertain submit retains address, same intent retry and committed receipt at320/text200',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      var calls = 0;
      final keys = <String>[];
      final api = FakeSyncareApi();
      api.onHomecareServices = (_) async =>
          const ServicePage([demoService], null);
      api.onRequestBooking = (id, input, key) async {
        keys.add(key);
        if (calls++ == 0) {
          throw apiExceptionForStatus(
            502,
            nestedErrorBody(
              'outcome_unknown',
              message: 'Hasil permintaan belum dapat dipastikan.',
              retryable: false,
            ),
          );
        }
        return bookingFixture();
      };
      final controller = BookingSubmitController(api, 'patient-a');
      controller.draftFields.addAll({
        'date': '2030-01-02',
        'start': '08:00',
        'end': '09:00',
      });
      await tester.pumpWidget(
        wrapScreen(
          BookingRequestScreen(serviceId: demoService.id),
          overrides: [
            bookingSubmitProvider.overrideWith((_) => controller),
            homecareCatalogProvider.overrideWith(
              (_) => HomecareCatalog(api, 'patient-a')..load(),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      for (final entry in {
        'address': 'Alamat sintetis nomor 1',
        'kelurahan': 'Kelurahan uji',
        'kecamatan': 'Kecamatan uji',
      }.entries) {
        final finder = find.widgetWithText(
          TextField,
          bookingFieldLabels[entry.key]!,
        );
        await tester.ensureVisible(finder);
        await tester.enterText(finder, entry.value);
      }
      final city = find.byType(DropdownButtonFormField<String>);
      await tester.ensureVisible(city);
      await tester.tap(city);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jakarta Pusat').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Kirim pengajuan'));
      await tester.tap(find.text('Kirim pengajuan'));
      await tester.pumpAndSettle();
      expect(find.text('Pengajuan tersimpan'), findsNothing);
      expect(controller.draftFields['address'], 'Alamat sintetis nomor 1');
      await tester.ensureVisible(find.text('Periksa pengajuan yang sama'));
      await tester.tap(find.text('Periksa pengajuan yang sama'));
      await tester.pumpAndSettle();
      expect(find.text('Pengajuan tersimpan'), findsOneWidget);
      expect(find.text('Status: Diajukan'), findsOneWidget);
      expect(
        find.textContaining('Belum ada jadwal atau petugas terkonfirmasi'),
        findsOneWidget,
      );
      expect(keys[0], keys[1]);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('empty catalog offers reload and never invents service', (
    tester,
  ) async {
    final api = FakeSyncareApi()
      ..onHomecareServices = (_) async => const ServicePage([], null);
    await tester.pumpWidget(
      wrapScreen(
        const HomecareScreen(),
        overrides: [
          homecareCatalogProvider.overrideWith(
            (_) => HomecareCatalog(api, 'patient-a')..load(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Belum ada layanan aktif'), findsOneWidget);
    expect(find.text('Ajukan kunjungan'), findsNothing);
    expect(find.text('Muat ulang katalog'), findsOneWidget);
  });
}
