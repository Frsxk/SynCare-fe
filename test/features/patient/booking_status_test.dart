import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncare_flutter/core/api_exception.dart';
import 'package:syncare_flutter/features/patient/homecare_providers.dart';
import 'package:syncare_flutter/features/patient/booking_detail_screen.dart';
import 'package:syncare_flutter/features/patient/booking_history_screen.dart';
import 'package:syncare_flutter/models/homecare.dart';
import '../../helpers/fakes.dart';
import '../../helpers/booking_lifecycle_fixture.dart';
import '../../helpers/pump_app.dart';

void main() {
  test(
    'cancel lost response preserves exact key/version/reason, doubletap once and terminal has no new mutation',
    () async {
      final pending = Completer<Booking>(),
          keys = <String>[],
          reasons = <String>[],
          versions = <int>[];
      final api = FakeSyncareApi()
        ..onGetBooking = (_) async => lifecycleFixture();
      api.onCancelBooking = (id, version, reason, key) {
        keys.add(key);
        versions.add(version);
        reasons.add(reason);
        return keys.length == 1
            ? pending.future
            : Future.value(lifecycleFixture(status: 'Cancelled'));
      };
      final controller = BookingDetailController(api, 'patient-a', 'booking-a');
      addTearDown(controller.dispose);
      await controller.load();
      final first = controller.cancel('Alasan asli');
      await controller.cancel('Doubletap');
      expect(keys.length, 1);
      expect(
        (controller.state as BookingReady).booking.status,
        BookingStatus.requested,
      );
      pending.completeError(const NetworkException());
      await first;
      expect((controller.state as BookingReady).feedback, isA<CancelUnknown>());
      await controller.cancel('Diedit setelah hasil belum pasti');
      expect(keys[0], keys[1]);
      expect(reasons, ['Alasan asli', 'Alasan asli']);
      expect(versions, [1, 1]);
      expect(
        (controller.state as BookingReady).feedback,
        isA<CancelCommitted>(),
      );
      await controller.cancel('Baru');
      expect(keys.length, 2);
    },
  );
  test(
    'stale cancel409 rereads Scheduled without success; refresh retains allowed detail and denied access clears it',
    () async {
      var scheduled = false;
      final api = FakeSyncareApi()
        ..onGetBooking = (_) async =>
            lifecycleFixture(status: scheduled ? 'Scheduled' : 'Under Review');
      api.onCancelBooking = (_, v, r, k) async {
        scheduled = true;
        throw const VersionConflictException();
      };
      final controller = BookingDetailController(api, 'patient-a', 'booking-a');
      addTearDown(controller.dispose);
      await controller.load();
      await controller.cancel('Alasan');
      expect(
        (controller.state as BookingReady).booking.status,
        BookingStatus.scheduled,
      );
      expect(
        (controller.state as BookingReady).feedback,
        isA<CancelConflict>(),
      );
      api.onGetBooking = (_) => throw const NetworkException();
      await controller.load();
      expect(
        (controller.state as BookingReady).booking.status,
        BookingStatus.scheduled,
      );
      expect((controller.state as BookingReady).error, isA<NetworkException>());
      api.onGetBooking = (_) => throw const ForbiddenException();
      await controller.load();
      expect(controller.state, isA<BookingDetailFailure>());
    },
  );
  test(
    'late GET cannot rewind a committed cancellation, disposed response cannot resurrect state',
    () async {
      final pending = Completer<Booking>();
      var reads = 0;
      final api = FakeSyncareApi()
        ..onGetBooking = (_) =>
            reads++ == 0 ? Future.value(lifecycleFixture()) : pending.future;
      api.onCancelBooking = (_, v, r, k) async =>
          lifecycleFixture(status: 'Cancelled');
      final controller = BookingDetailController(api, 'patient-a', 'booking-a');
      await controller.load();
      final refresh = controller.load();
      await controller.cancel('Alasan');
      pending.complete(lifecycleFixture());
      await refresh;
      expect(
        (controller.state as BookingReady).booking.status,
        BookingStatus.cancelled,
      );
      controller.dispose();
      final later = Completer<Booking>();
      api.onGetBooking = (_) => later.future;
      final disposed = BookingDetailController(api, 'patient-a', 'booking-a');
      final read = disposed.load();
      disposed.dispose();
      later.complete(lifecycleFixture());
      await read;
    },
  );
  test(
    'own history paginates/deduplicates, reloads actual state, rejects foreign response and clears forbidden cache',
    () async {
      final api = FakeSyncareApi()
        ..onListBookings = (id, cursor) async => cursor == null
            ? BookingPage([lifecycleFixture()], 'next')
            : BookingPage([
                lifecycleFixture(),
                lifecycleFixture(id: 'booking-b', status: 'Rejected'),
              ], null);
      final controller = BookingHistoryController(api, 'patient-a');
      addTearDown(controller.dispose);
      await controller.load();
      await controller.load(next: true);
      expect(controller.state.valueOrNull?.bookings.length, 2);
      api.onListBookings = (id, cursor) async =>
          BookingPage([lifecycleFixture(status: 'Cancelled')], null);
      await controller.load();
      expect(
        controller.state.valueOrNull?.bookings.single.status,
        BookingStatus.cancelled,
      );
      api.onListBookings = (id, cursor) async =>
          BookingPage([lifecycleFixture(patientId: 'foreign')], null);
      await controller.load();
      expect(controller.state.error, isA<InvalidResponseException>());
      api.onListBookings = (id, cursor) => throw const ForbiddenException();
      await controller.load();
      expect(controller.state.valueOrNull, isNull);
    },
  );
  test(
    'all six states parse exact nullable fields; malformed completion, timeline internal note and unknown state fail closed',
    () {
      for (final status in [
        'Requested',
        'Under Review',
        'Scheduled',
        'Completed',
        'Cancelled',
        'Rejected',
      ]) {
        expect(
          lifecycleFixture(status: status).status,
          BookingStatus.parse(status),
        );
      }
      expect(
        () => Booking.fromJson({
          ...lifecycleJson(status: 'Completed'),
          'completionNote': null,
        }),
        throwsA(isA<InvalidResponseException>()),
      );
      final private = lifecycleJson();
      (private['timeline'] as List).first['internalNote'] = 'private';
      expect(
        () => Booking.fromJson(private),
        throwsA(isA<InvalidResponseException>()),
      );
      expect(
        () => Booking.fromJson(lifecycleJson(status: 'Unknown')),
        throwsA(isA<InvalidResponseException>()),
      );
    },
  );
  testWidgets(
    'all six status views separate preference/confirmed/history/actual closure at320/text200',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final status in [
        'Requested',
        'Under Review',
        'Scheduled',
        'Completed',
        'Cancelled',
        'Rejected',
      ]) {
        final reason = TextEditingController(),
            booking = lifecycleFixture(
              status: status,
              cancelledAfterSchedule: status == 'Cancelled',
            );
        await tester.pumpWidget(
          wrapScreen(
            Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(24),
                  child: BookingDetailContent(
                    state: BookingReady(booking),
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
        expect(find.text('Status: ${booking.status.label}'), findsOneWidget);
        expect(find.textContaining('ID booking:'), findsNothing);
        expect(find.textContaining('Pencatat:'), findsNothing);
        if (status == 'Scheduled') {
          expect(find.text('Batalkan pengajuan'), findsNothing);
          expect(find.text('Jadwal terkonfirmasi'), findsOneWidget);
        }
        if (status == 'Cancelled') {
          expect(find.text('Riwayat jadwal'), findsOneWidget);
          expect(find.text('Jadwal terkonfirmasi'), findsNothing);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        reason.dispose();
      }
    },
  );
  testWidgets(
    'patient cancellation has no optimistic status, retains reason on lost response and same-key retry commits',
    (tester) async {
      final pending = Completer<Booking>();
      var calls = 0;
      final api = FakeSyncareApi()
        ..onGetBooking = (_) async => lifecycleFixture();
      api.onCancelBooking = (_, v, r, k) => calls++ == 0
          ? pending.future
          : Future.value(lifecycleFixture(status: 'Cancelled'));
      final controller = BookingDetailController(api, 'patient-a', 'booking-a');
      await tester.pumpWidget(
        wrapScreen(
          const BookingDetailScreen(bookingId: 'booking-a'),
          overrides: [
            bookingDetailProvider(
              'booking-a',
            ).overrideWith((_) => controller..load()),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final field = find.widgetWithText(TextField, 'Alasan pembatalan');
      await tester.ensureVisible(field);
      await tester.enterText(field, 'Alasan tetap');
      await tester.ensureVisible(find.text('Batalkan pengajuan'));
      await tester.tap(find.text('Batalkan pengajuan'));
      await tester.pump();
      expect(find.text('Status: Dibatalkan'), findsNothing);
      pending.completeError(const NetworkException());
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, 'Alasan tetap');
      await tester.ensureVisible(find.text('Periksa pembatalan yang sama'));
      await tester.tap(find.text('Periksa pembatalan yang sama'));
      await tester.pumpAndSettle();
      expect(find.text('Status: Dibatalkan'), findsOneWidget);
      expect(find.text('Pembatalan tersimpan.'), findsOneWidget);
    },
  );
  testWidgets('empty patient history shows reload without inventing booking', (
    tester,
  ) async {
    final api = FakeSyncareApi()
      ..onListBookings = (id, cursor) async => const BookingPage([], null);
    await tester.pumpWidget(
      wrapScreen(
        const BookingHistoryScreen(),
        overrides: [
          bookingHistoryProvider.overrideWith(
            (_) => BookingHistoryController(api, 'patient-a')..load(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Belum ada booking tersimpan'), findsOneWidget);
    expect(find.text('Muat ulang booking'), findsOneWidget);
    expect(find.text('Buka detail booking'), findsNothing);
  });
}
