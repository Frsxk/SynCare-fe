import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/approved_plan.dart';
import '../models/discharge_result.dart';
import '../models/plan_draft.dart';
import 'api_client.dart';
import 'config.dart';
import 'sse.dart';

final tokenSourceProvider = Provider<TokenSource>((ref) => SecureTokenSource());

final apiProvider = Provider<SyncareApi>(
  (ref) => ApiClient(
    baseUrl: AppConfig.apiBase,
    tokenSource: ref.watch(tokenSourceProvider),
  ),
);

final f1ResultProvider = StateProvider<DischargeResult?>((ref) => null);

final draftResultProvider = StateProvider<PlanDraft?>((ref) => null);

final plansProvider = FutureProvider.autoDispose<PlansResponse>(
  (ref) => ref.watch(apiProvider).listPlans(),
);

final approvedPlanProvider = FutureProvider.autoDispose
    .family<ApprovedPlanRecord, String>(
      (ref, patientId) => ref.watch(apiProvider).getPlan(patientId),
    );

final patientIdProvider = NotifierProvider<PatientIdController, String>(
  PatientIdController.new,
);

class PatientIdController extends Notifier<String> {
  static const String _prefsKey = 'patient_id';

  bool _disposed = false;
  bool _hasLocalValue = false;

  @override
  String build() {
    ref.onDispose(() => _disposed = true);
    _load();
    return AppConfig.defaultPatientId;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_prefsKey)?.trim();
      if (!_disposed &&
          !_hasLocalValue &&
          stored != null &&
          stored.isNotEmpty) {
        state = stored;
      }
    } on Exception {
      // Preferences are best-effort; the compile-time default stays.
    }
  }

  Future<void> setPatientId(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _hasLocalValue = true;
    if (!_disposed) {
      state = trimmed;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, trimmed);
    } on Exception {
      // The in-memory value is still authoritative for this session.
    }
  }
}

final reviewEventsProvider = Provider<ReviewEventSource>(
  (ref) => HttpReviewEventSource(
    baseUrl: AppConfig.apiBase,
    tokenSource: ref.watch(tokenSourceProvider),
  ),
);
