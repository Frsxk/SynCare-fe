import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/providers.dart';
import '../../models/homecare.dart';
import 'checkin_providers.dart';

final homecareCatalogProvider =
    StateNotifierProvider.autoDispose<HomecareCatalog, AsyncValue<ServicePage>>(
      (ref) {
        final patient = ownCheckinPatient(ref);
        return HomecareCatalog(ref.watch(apiProvider), patient)..load();
      },
    );

class HomecareCatalog extends StateNotifier<AsyncValue<ServicePage>> {
  HomecareCatalog(this.api, this.patientId)
    : super(
        patientId == null
            ? AsyncError(const UnauthorizedException(), StackTrace.empty)
            : const AsyncLoading(),
      );
  final SyncareApi api;
  final String? patientId;
  bool _busy = false;
  Future<void> load({bool next = false}) async {
    if (_busy || patientId == null) return;
    final old = state.valueOrNull,
        cursor = next ? state.valueOrNull?.nextCursor : null;
    if (next && cursor == null) return;
    _busy = true;
    state = const AsyncLoading<ServicePage>().copyWithPrevious(state);
    try {
      final page = await api.listHomecareServices(cursor: cursor);
      if (!mounted) return;
      final items = next
          ? [...?old?.services, ...page.services]
          : page.services;
      state = AsyncData(ServicePage(items, page.nextCursor));
    } catch (error, stack) {
      if (!mounted) return;
      final denied =
          error is UnauthorizedException ||
          error is ForbiddenException ||
          error is NotFoundException;
      state = denied
          ? AsyncError(error, stack)
          : AsyncError<ServicePage>(error, stack).copyWithPrevious(state);
    } finally {
      _busy = false;
    }
  }
}

sealed class BookingSubmitState {
  const BookingSubmitState();
}

class BookingDraft extends BookingSubmitState {
  const BookingDraft({this.error});
  final Object? error;
}

class BookingSending extends BookingSubmitState {
  const BookingSending();
}

class BookingUnknown extends BookingSubmitState {
  const BookingUnknown(this.error);
  final Object error;
}

class BookingUnavailable extends BookingSubmitState {
  const BookingUnavailable(this.error);
  final Object error;
}

class BookingSaved extends BookingSubmitState {
  const BookingSaved(this.booking);
  final Booking booking;
}

final bookingSubmitProvider =
    StateNotifierProvider<BookingSubmitController, BookingSubmitState>(
      (ref) => BookingSubmitController(
        ref.watch(apiProvider),
        ownCheckinPatient(ref),
      ),
    );

class BookingSubmitController extends StateNotifier<BookingSubmitState> {
  BookingSubmitController(this.api, this.patientId)
    : super(
        patientId == null
            ? const BookingUnavailable(UnauthorizedException())
            : const BookingDraft(),
      );
  final SyncareApi api;
  final String? patientId;
  ({BookingInput input, String key})? _intent;
  final Map<String, String> draftFields = {};
  Future<void> submit(BookingInput input) async {
    if (patientId == null ||
        state is BookingUnavailable ||
        state is BookingSending ||
        state is BookingSaved) {
      return;
    }
    _intent ??= (input: input, key: requestUuid());
    final intent = _intent!;
    state = const BookingSending();
    try {
      final result = await api.requestBooking(
        patientId: patientId!,
        input: intent.input,
        requestKey: intent.key,
      );
      if (!mounted) return;
      if (result.patientId != patientId ||
          result.service.id != intent.input.serviceId) {
        throw const InvalidResponseException();
      }
      state = BookingSaved(result);
    } catch (error) {
      if (!mounted) return;
      if (error is UnauthorizedException ||
          error is ForbiddenException ||
          error is NotFoundException) {
        state = BookingUnavailable(error);
        draftFields.clear();
        _intent = null;
      } else if (error is ValidationException) {
        _intent = null;
        state = BookingDraft(error: error);
      } else {
        state = BookingUnknown(error);
      }
    }
  }

  Future<void> reconcile() async {
    final intent = _intent;
    if (intent != null) await submit(intent.input);
  }

  void startNew() {
    if (state is! BookingSaved) return;
    _intent = null;
    draftFields.clear();
    state = const BookingDraft();
  }
}

final bookingHistoryProvider =
    StateNotifierProvider.autoDispose<
      BookingHistoryController,
      AsyncValue<BookingPage>
    >(
      (ref) => BookingHistoryController(
        ref.watch(apiProvider),
        ownCheckinPatient(ref),
      )..load(),
    );

class BookingHistoryController extends StateNotifier<AsyncValue<BookingPage>> {
  BookingHistoryController(this.api, this.patientId)
    : super(
        patientId == null
            ? AsyncError(const UnauthorizedException(), StackTrace.empty)
            : const AsyncLoading(),
      );
  final SyncareApi api;
  final String? patientId;
  bool _busy = false;
  Future<void> load({bool next = false}) async {
    if (_busy || patientId == null) return;
    final previous = state.valueOrNull,
        cursor = next ? state.valueOrNull?.nextCursor : null;
    if (next && cursor == null) return;
    _busy = true;
    state = const AsyncLoading<BookingPage>().copyWithPrevious(state);
    try {
      final page = await api.listBookings(patientId!, cursor: cursor);
      if (!mounted) return;
      if (page.bookings.any((b) => b.patientId != patientId)) {
        throw const InvalidResponseException();
      }
      final rows = next
          ? [...?previous?.bookings, ...page.bookings]
          : page.bookings;
      state = AsyncData(
        BookingPage(
          {for (final row in rows) row.id: row}.values.toList(growable: false),
          page.nextCursor,
        ),
      );
    } catch (error, stack) {
      if (!mounted) return;
      state = _bookingDenied(error)
          ? AsyncError(error, stack)
          : AsyncError<BookingPage>(error, stack).copyWithPrevious(state);
    } finally {
      _busy = false;
    }
  }
}

bool _bookingDenied(Object error) =>
    error is UnauthorizedException ||
    error is ForbiddenException ||
    error is NotFoundException;

sealed class CancelFeedback {
  const CancelFeedback();
}

class CancelIdle extends CancelFeedback {
  const CancelIdle();
}

class CancelSending extends CancelFeedback {
  const CancelSending();
}

class CancelUnknown extends CancelFeedback {
  const CancelUnknown(this.error);
  final Object error;
}

class CancelConflict extends CancelFeedback {
  const CancelConflict(this.error);
  final Object error;
}

class CancelRejected extends CancelFeedback {
  const CancelRejected(this.error);
  final Object error;
}

class CancelCommitted extends CancelFeedback {
  const CancelCommitted();
}

sealed class BookingDetailState {
  const BookingDetailState();
}

class BookingDetailLoading extends BookingDetailState {
  const BookingDetailLoading();
}

class BookingDetailFailure extends BookingDetailState {
  const BookingDetailFailure(this.error);
  final Object error;
}

class BookingReady extends BookingDetailState {
  const BookingReady(
    this.booking, {
    this.refreshing = false,
    this.error,
    this.feedback = const CancelIdle(),
  });
  final Booking booking;
  final bool refreshing;
  final Object? error;
  final CancelFeedback feedback;
}

final bookingDetailProvider = StateNotifierProvider.autoDispose
    .family<BookingDetailController, BookingDetailState, String>(
      (ref, id) => BookingDetailController(
        ref.watch(apiProvider),
        ownCheckinPatient(ref),
        id,
      )..load(),
    );

class BookingDetailController extends StateNotifier<BookingDetailState> {
  BookingDetailController(this.api, this.patientId, this.bookingId)
    : super(
        patientId == null
            ? const BookingDetailFailure(UnauthorizedException())
            : const BookingDetailLoading(),
      );
  final SyncareApi api;
  final String? patientId;
  final String bookingId;
  ({int version, String reason, String key})? _intent;
  int _epoch = 0;
  bool _reading = false;
  void _validate(Booking booking) {
    if (booking.id != bookingId || booking.patientId != patientId) {
      throw const InvalidResponseException();
    }
  }

  Future<void> load() async {
    if (patientId == null || _reading) return;
    final old = state;
    if (old is BookingReady && old.feedback is CancelSending) return;
    final epoch = ++_epoch;
    _reading = true;
    if (old is BookingReady) {
      state = BookingReady(
        old.booking,
        refreshing: true,
        feedback: old.feedback,
      );
    } else {
      state = const BookingDetailLoading();
    }
    try {
      final booking = await api.getBooking(bookingId);
      if (!mounted || epoch != _epoch) return;
      _validate(booking);
      state = BookingReady(
        booking,
        feedback: old is BookingReady ? old.feedback : const CancelIdle(),
      );
    } catch (error) {
      if (!mounted || epoch != _epoch) return;
      if (_bookingDenied(error)) {
        _intent = null;
        state = BookingDetailFailure(error);
      } else {
        state = old is BookingReady
            ? BookingReady(old.booking, error: error, feedback: old.feedback)
            : BookingDetailFailure(error);
      }
    } finally {
      if (epoch == _epoch) _reading = false;
    }
  }

  Future<void> cancel(String reason) async {
    final old = state;
    if (old is! BookingReady ||
        old.feedback is CancelSending ||
        patientId == null) {
      return;
    }
    if (_intent == null && !old.booking.canCancel) return;
    if (_intent == null &&
        (reason.trim().isEmpty || reason.trim().length > 2000)) {
      state = BookingReady(
        old.booking,
        feedback: const CancelRejected(
          ValidationException('Isi alasan pembatalan, maksimal 2000 karakter.'),
        ),
      );
      return;
    }
    _intent ??= (
      version: old.booking.version,
      reason: reason.trim(),
      key: requestUuid(),
    );
    final intent = _intent!, epoch = ++_epoch;
    _reading = false;
    state = BookingReady(old.booking, feedback: const CancelSending());
    try {
      final booking = await api.cancelBooking(
        bookingId: bookingId,
        expectedVersion: intent.version,
        reason: intent.reason,
        requestKey: intent.key,
      );
      if (!mounted || epoch != _epoch) return;
      _validate(booking);
      if (booking.status != BookingStatus.cancelled) {
        throw const InvalidResponseException();
      }
      _intent = null;
      state = BookingReady(booking, feedback: const CancelCommitted());
    } catch (error) {
      if (!mounted || epoch != _epoch) return;
      if (_bookingDenied(error)) {
        _intent = null;
        state = BookingDetailFailure(error);
      } else if (error is VersionConflictException ||
          error is IdempotencyConflictException) {
        _intent = null;
        state = BookingReady(old.booking, feedback: CancelConflict(error));
        await load();
      } else if (error is ValidationException) {
        _intent = null;
        state = BookingReady(old.booking, feedback: CancelRejected(error));
      } else {
        state = BookingReady(old.booking, feedback: CancelUnknown(error));
      }
    }
  }

  Future<void> reconcile() async {
    final intent = _intent;
    if (intent != null) await cancel(intent.reason);
  }
}
