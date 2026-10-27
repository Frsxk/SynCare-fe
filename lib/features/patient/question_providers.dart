import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/providers.dart';
import '../../models/ask_answer.dart';
import 'checkin_providers.dart';

final questionProvider =
    StateNotifierProvider.autoDispose<
      QuestionController,
      AsyncValue<QuestionOutcome?>
    >(
      (ref) =>
          QuestionController(ref.watch(apiProvider), ownCheckinPatient(ref)),
    );

class QuestionController extends StateNotifier<AsyncValue<QuestionOutcome?>> {
  QuestionController(this.api, this.patientId)
    : super(
        patientId == null
            ? AsyncError(const UnauthorizedException(), StackTrace.empty)
            : const AsyncData(null),
      );
  final SyncareApi api;
  final String? patientId;
  bool _busy = false;
  String? _lastQuery;
  Future<void> submit(String input) async {
    if (_busy || patientId == null) return;
    final query = input.trim();
    if (query.isEmpty || query.length > 2000) {
      state = AsyncError(
        const ValidationException(
          'Tulis pertanyaan antara 1 dan 2000 karakter.',
        ),
        StackTrace.empty,
      );
      return;
    }
    _busy = true;
    _lastQuery = query;
    state = const AsyncLoading();
    try {
      final outcome = await api.ask(patientId: patientId!, query: query);
      if (mounted) state = AsyncData(outcome);
    } catch (error, stack) {
      if (mounted) state = AsyncError(error, stack);
    } finally {
      _busy = false;
    }
  }

  Future<void> retry() async {
    final query = _lastQuery;
    if (query != null) await submit(query);
  }
}
