import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/approved_plan.dart';
import '../models/discharge_result.dart';
import '../models/plan_draft.dart';
import '../models/session.dart';
import '../features/auth/session_controller.dart';
import 'api_client.dart';
import 'config.dart';
import 'sse.dart';

export 'session_api.dart' show tokenSourceProvider;

final sessionDioFactoryProvider = Provider<Dio Function()>((ref) => Dio.new);
final apiBaseUrlProvider = Provider<String>(
  (ref) => validateSessionBaseUrl(AppConfig.apiBase),
);

final apiProvider = Provider<SyncareApi>((ref) {
  final session = ref.watch(sessionControllerProvider);
  final controller = ref.read(sessionControllerProvider.notifier);
  final dio = ref.read(sessionDioFactoryProvider)();
  ref.onDispose(() => dio.close(force: true));
  dio.interceptors.add(
    InterceptorsWrapper(
      onResponse: (response, handler) {
        if (controller.tokenFor(session.generation) == null) {
          handler.reject(
            DioException(
              requestOptions: response.requestOptions,
              type: DioExceptionType.cancel,
            ),
          );
        } else {
          handler.next(response);
        }
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401 &&
            controller.tokenFor(session.generation) != null) {
          unawaited(controller.expire());
        }
        handler.next(error);
      },
    ),
  );
  return ApiClient(
    baseUrl: ref.watch(apiBaseUrlProvider),
    tokenSource: GenerationTokenSource(controller, session.generation),
    dio: dio,
  );
});

final f1ResultProvider = StateProvider<DischargeResult?>((ref) {
  ref.watch(sessionControllerProvider.select((state) => state.generation));
  return null;
});

final draftResultProvider = StateProvider<PlanDraft?>((ref) {
  ref.watch(sessionControllerProvider.select((state) => state.generation));
  return null;
});

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
  int _generation = 0;

  @override
  String build() {
    final identity = ref.watch(
      sessionControllerProvider.select(
        (session) => session is SessionAuthenticated
            ? (
                session.session.principal.id,
                session.session.principal.role,
                session.session.principal.patientId,
              )
            : null,
      ),
    );
    final generation = ++_generation;
    _disposed = false;
    _hasLocalValue = false;
    ref.onDispose(() {
      _disposed = true;
      _generation++;
    });
    if (identity != null) {
      _hasLocalValue = true;
      return identity.$2 == 'patient' ? identity.$3! : '';
    }
    _load(generation);
    return AppConfig.defaultPatientId;
  }

  Future<void> _load(int generation) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_prefsKey)?.trim();
      if (!_disposed &&
          generation == _generation &&
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
    final session = ref.read(sessionControllerProvider);
    if (session is SessionAuthenticated &&
        session.session.principal.role == 'patient') {
      return;
    }
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

final reviewEventsProvider = Provider<ReviewEventSource>((ref) {
  final session = ref.watch(sessionControllerProvider);
  final client = http.Client();
  ref.onDispose(client.close);
  return HttpReviewEventSource(
    baseUrl: validateSessionBaseUrl(AppConfig.apiBase),
    tokenSource: GenerationTokenSource(
      ref.read(sessionControllerProvider.notifier),
      session.generation,
    ),
    client: client,
  );
});
