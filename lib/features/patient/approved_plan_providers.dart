import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/providers.dart';
import '../../models/verified_care_plan.dart';
import 'checkin_providers.dart';

final verifiedPlansProvider =
    StateNotifierProvider.autoDispose<
      VerifiedPlans,
      AsyncValue<VerifiedPlanPage>
    >(
      (ref) =>
          VerifiedPlans(ref.watch(apiProvider), ownCheckinPatient(ref))..load(),
    );

class VerifiedPlans extends StateNotifier<AsyncValue<VerifiedPlanPage>> {
  VerifiedPlans(this.api, this.patientId)
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
    state = const AsyncLoading<VerifiedPlanPage>().copyWithPrevious(state);
    try {
      final page = await api.listVerifiedPlans(patientId!, cursor: cursor);
      if (!mounted) return;
      if (page.plans.any((p) => p.record.patientId != patientId)) {
        throw const InvalidResponseException();
      }
      final rows = next ? [...?old?.plans, ...page.plans] : page.plans;
      state = AsyncData(
        VerifiedPlanPage(
          {for (final row in rows) row.id: row}.values.toList(growable: false),
          page.nextCursor,
        ),
      );
    } catch (error, stack) {
      if (mounted) {
        state =
            error is UnauthorizedException ||
                error is ForbiddenException ||
                error is NotFoundException
            ? AsyncError(error, stack)
            : AsyncError<VerifiedPlanPage>(
                error,
                stack,
              ).copyWithPrevious(state);
      }
    } finally {
      _busy = false;
    }
  }
}
