import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/providers.dart';
import '../../models/escalation.dart';
import 'checkin_providers.dart';

bool _denied(Object error) =>
    error is UnauthorizedException ||
    error is ForbiddenException ||
    error is NotFoundException;
final alertHistoryProvider =
    StateNotifierProvider.autoDispose<AlertHistory, AsyncValue<EscalationPage>>(
      (ref) =>
          AlertHistory(ref.watch(apiProvider), ownCheckinPatient(ref))..load(),
    );

class AlertHistory extends StateNotifier<AsyncValue<EscalationPage>> {
  AlertHistory(this.api, this.patientId)
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
    state = const AsyncLoading<EscalationPage>().copyWithPrevious(state);
    try {
      final page = await api.listEscalations(patientId!, cursor: cursor);
      if (!mounted) return;
      if (page.alerts.any((a) => a.patientId != patientId)) {
        throw const InvalidResponseException();
      }
      final rows = next ? [...?old?.alerts, ...page.alerts] : page.alerts;
      state = AsyncData(
        EscalationPage(
          {for (final row in rows) row.id: row}.values.toList(growable: false),
          page.nextCursor,
        ),
      );
    } catch (error, stack) {
      if (mounted) {
        state = _denied(error)
            ? AsyncError(error, stack)
            : AsyncError<EscalationPage>(error, stack).copyWithPrevious(state);
      }
    } finally {
      _busy = false;
    }
  }
}

final alertDetailProvider = StateNotifierProvider.autoDispose
    .family<AlertDetailController, AsyncValue<Escalation>, String>(
      (ref, id) => AlertDetailController(
        ref.watch(apiProvider),
        ownCheckinPatient(ref),
        id,
      )..load(),
    );

class AlertDetailController extends StateNotifier<AsyncValue<Escalation>> {
  AlertDetailController(this.api, this.patientId, this.id)
    : super(
        patientId == null
            ? AsyncError(const UnauthorizedException(), StackTrace.empty)
            : const AsyncLoading(),
      );
  final SyncareApi api;
  final String? patientId;
  final String id;
  bool _busy = false;
  Future<void> load({bool older = false}) async {
    if (_busy || patientId == null) return;
    final old = state.valueOrNull,
        cursor = older ? state.valueOrNull?.timelineNextCursor : null;
    if (older && cursor == null) return;
    _busy = true;
    state = const AsyncLoading<Escalation>().copyWithPrevious(state);
    try {
      var alert = await api.getEscalation(id, cursor: cursor);
      if (!mounted) return;
      if (older && old != null) {
        if (alert.version != old.version) {
          alert = await api.getEscalation(id);
          if (!mounted) return;
        } else {
          final entries = {
            for (final row in [...old.timeline, ...alert.timeline]) row.id: row,
          }.values.toList()..sort((a, b) => a.version.compareTo(b.version));
          alert = alert.withHistory(entries, alert.timelineNextCursor);
        }
      }
      if (alert.patientId != patientId || alert.id != id) {
        throw const InvalidResponseException();
      }
      state = AsyncData(alert);
    } catch (error, stack) {
      if (mounted) {
        state = _denied(error)
            ? AsyncError(error, stack)
            : AsyncError<Escalation>(error, stack).copyWithPrevious(state);
      }
    } finally {
      _busy = false;
    }
  }
}
