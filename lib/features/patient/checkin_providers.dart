import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/providers.dart';
import '../../models/checkin_record.dart';
import '../../models/session.dart';
import '../auth/session_controller.dart';

String? ownCheckinPatient(Ref ref) {
  final state = ref.watch(sessionControllerProvider);
  if (state is! SessionAuthenticated ||
      state.session.principal.role != 'patient') {
    return null;
  }
  return state.session.principal.patientId!;
}

String requestUuid() {
  final random = Random.secure(),
      bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

sealed class CheckinSubmitState {
  const CheckinSubmitState();
}

class CheckinDraft extends CheckinSubmitState {
  const CheckinDraft({this.error});
  final Object? error;
}

class CheckinUnavailable extends CheckinSubmitState {
  const CheckinUnavailable(this.error);
  final Object error;
}

class CheckinSending extends CheckinSubmitState {
  const CheckinSending();
}

class CheckinSendFailure extends CheckinSubmitState {
  const CheckinSendFailure(this.error);
  final Object error;
}

class CheckinSaved extends CheckinSubmitState {
  const CheckinSaved(this.record, {this.refreshing = false, this.error});
  final CheckinRecord record;
  final bool refreshing;
  final Object? error;
}

final checkinSubmitProvider =
    StateNotifierProvider<CheckinSubmitController, CheckinSubmitState>((ref) {
      final patientId = ownCheckinPatient(ref), api = ref.watch(apiProvider);
      return CheckinSubmitController(api, patientId);
    });

class CheckinSubmitController extends StateNotifier<CheckinSubmitState> {
  CheckinSubmitController(this.api, this.patientId)
    : super(
        patientId == null
            ? const CheckinUnavailable(UnauthorizedException())
            : const CheckinDraft(),
      );
  final SyncareApi api;
  final String? patientId;
  ({String message, String key})? _intent;
  String? _draftMessage;
  Timer? _poll;
  int _polls = 0;
  int _generation = 0;
  String get message => _intent?.message ?? _draftMessage ?? '';
  Future<void> submit(String message) async {
    final ownId = patientId;
    if (ownId == null || state is CheckinUnavailable) return;
    if (state is CheckinSending || state is CheckinSaved) return;
    if (message.trim().isEmpty) return;
    _intent ??= (message: message, key: requestUuid());
    final intent = _intent!;
    _draftMessage = intent.message;
    final generation = _generation;
    state = const CheckinSending();
    try {
      final record = await api.submitCheckin(
        patientId: ownId,
        message: intent.message,
        requestKey: intent.key,
      );
      if (!mounted || generation != _generation) return;
      if (record.patientId != patientId) throw const InvalidResponseException();
      _draftMessage = null;
      state = CheckinSaved(record);
      _schedule(record);
    } catch (error) {
      if (mounted && generation == _generation) {
        if (error is ValidationException) {
          // A 422 is a definitive rejection: nothing was stored, so the
          // patient may correct the draft. The rejected text stays available
          // and the next submit is a new intent with a new key.
          _intent = null;
          _draftMessage = intent.message;
          state = CheckinDraft(error: error);
        } else if (error is UnauthorizedException ||
            error is ForbiddenException ||
            error is NotFoundException) {
          state = CheckinUnavailable(error);
        } else {
          state = CheckinSendFailure(error);
        }
      }
    }
  }

  Future<void> reconcile() async {
    final intent = _intent;
    if (intent != null) await submit(intent.message);
  }

  Future<void> refresh() async {
    final previous = state;
    if (previous is! CheckinSaved || previous.refreshing) return;
    final generation = _generation;
    _poll?.cancel();
    state = CheckinSaved(previous.record, refreshing: true);
    try {
      final record = await api.getCheckin(previous.record.id);
      if (!mounted || generation != _generation) return;
      if (record.patientId != patientId || record.id != previous.record.id) {
        throw const InvalidResponseException();
      }
      state = CheckinSaved(record);
      _schedule(record);
    } catch (error) {
      if (!mounted || generation != _generation) return;
      state =
          error is UnauthorizedException ||
              error is ForbiddenException ||
              error is NotFoundException
          ? CheckinUnavailable(error)
          : CheckinSaved(previous.record, error: error);
    }
  }

  void _schedule(CheckinRecord record) {
    _poll?.cancel();
    if (record.processing.isPending && _polls++ < 30) {
      _poll = Timer(const Duration(seconds: 2), refresh);
    }
  }

  void startNew() {
    if (state is! CheckinSaved) return;
    _generation++;
    _poll?.cancel();
    _intent = null;
    _draftMessage = null;
    _polls = 0;
    state = const CheckinDraft();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }
}

final emergencyGuidanceProvider = FutureProvider.autoDispose<EmergencyGuidance>(
  (ref) => ref.watch(apiProvider).getEmergencyGuidance(),
);
final checkinHistoryProvider =
    StateNotifierProvider.autoDispose<
      CheckinHistoryController,
      AsyncValue<CheckinPage>
    >((ref) {
      final patientId = ownCheckinPatient(ref), api = ref.watch(apiProvider);
      return CheckinHistoryController(api, patientId)..load();
    });

class CheckinHistoryController extends StateNotifier<AsyncValue<CheckinPage>> {
  CheckinHistoryController(this.api, this.patientId)
    : super(
        patientId == null
            ? AsyncError(const UnauthorizedException(), StackTrace.empty)
            : const AsyncLoading(),
      );
  final SyncareApi api;
  final String? patientId;
  bool _busy = false;
  Future<void> load({bool next = false}) async {
    final ownId = patientId;
    if (ownId == null) return;
    if (_busy) return;
    final old = state.valueOrNull;
    if (next && old?.nextCursor == null) return;
    _busy = true;
    state = const AsyncLoading<CheckinPage>().copyWithPrevious(state);
    try {
      final page = await api.listCheckins(
        ownId,
        cursor: next ? old?.nextCursor : null,
      );
      if (!mounted) return;
      if (page.records.any((r) => r.patientId != patientId)) {
        throw const InvalidResponseException();
      }
      state = AsyncData(
        next
            ? CheckinPage([...old!.records, ...page.records], page.nextCursor)
            : page,
      );
    } catch (error, stack) {
      if (mounted) {
        state =
            error is UnauthorizedException ||
                error is ForbiddenException ||
                error is NotFoundException
            ? AsyncError(error, stack)
            : AsyncError<CheckinPage>(error, stack).copyWithPrevious(state);
      }
    } finally {
      _busy = false;
    }
  }
}

final checkinDetailProvider = StateNotifierProvider.autoDispose
    .family<CheckinDetailController, AsyncValue<CheckinRecord>, String>((
      ref,
      id,
    ) {
      final patientId = ownCheckinPatient(ref), api = ref.watch(apiProvider);
      return CheckinDetailController(api, patientId, id)..load();
    });

class CheckinDetailController extends StateNotifier<AsyncValue<CheckinRecord>> {
  CheckinDetailController(this.api, this.patientId, this.id)
    : super(
        patientId == null
            ? AsyncError(const UnauthorizedException(), StackTrace.empty)
            : const AsyncLoading(),
      );
  final SyncareApi api;
  final String? patientId;
  final String id;
  Timer? _poll;
  int _polls = 0;
  bool _busy = false;
  Future<void> load() async {
    if (patientId == null) return;
    if (_busy) return;
    _poll?.cancel();
    _busy = true;
    state = const AsyncLoading<CheckinRecord>().copyWithPrevious(state);
    try {
      final report = await api.getCheckin(id);
      if (!mounted) return;
      if (report.patientId != patientId) throw const InvalidResponseException();
      state = AsyncData(report);
      if (report.processing.isPending && _polls++ < 30) {
        _poll = Timer(const Duration(seconds: 2), load);
      }
    } catch (error, stack) {
      if (mounted) {
        state =
            error is UnauthorizedException ||
                error is ForbiddenException ||
                error is NotFoundException
            ? AsyncError(error, stack)
            : AsyncError<CheckinRecord>(error, stack).copyWithPrevious(state);
      }
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }
}
