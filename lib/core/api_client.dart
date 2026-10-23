import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/approved_plan.dart';
import '../models/ask_answer.dart';
import '../models/checkin_result.dart';
import '../models/discharge_result.dart';
import '../models/health.dart';
import '../models/plan_draft.dart';
import '../models/review_job.dart';
import 'api_exception.dart';
import 'config.dart';

/// The SynCare backend surface used by the app.
abstract class SyncareApi {
  Future<Health> health();
  Future<DischargeResult> discharge(String summary);
  Future<CheckinResult> checkin({
    required String patientId,
    required String message,
  });
  Future<PlanDraft> draftPlan({
    required String patientId,
    required String followupDate,
    required String hotline,
    required DischargeResult f1ScoredOutput,
  });
  Future<ReviewJob> startReview({required String draftJson});
  Future<void> resumeReview({
    required String jobId,
    required String requestId,
    required String actionId,
    required String actor,
    String reviewerNote = '',
  });
  Future<AskAnswer> ask({required String patientId, required String query});
  Future<PlansResponse> listPlans();
  Future<ApprovedPlanRecord> getPlan(String patientId);
}

/// Dio-backed implementation of [SyncareApi].
class ApiClient implements SyncareApi {
  ApiClient({required String baseUrl, required this._tokenSource, Dio? dio})
    : _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = _normalizeBaseUrl(baseUrl)
      ..connectTimeout = const Duration(seconds: 10)
      ..receiveTimeout = const Duration(seconds: 180)
      ..sendTimeout = const Duration(seconds: 30)
      ..contentType = Headers.jsonContentType
      ..responseType = ResponseType.json;
    _dio.options.headers['Accept'] = Headers.jsonContentType;
    _dio.interceptors.add(InterceptorsWrapper(onRequest: _interceptRequest));
  }

  final TokenSource _tokenSource;
  final Dio _dio;

  void _interceptRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    _attachToken(options, handler);
  }

  Future<void> _attachToken(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    String? token;
    try {
      token = await _tokenSource.read();
    } on Exception {
      handler.reject(
        DioException(
          requestOptions: options,
          error: const UnauthorizedException(),
        ),
      );
      return;
    }
    if (token == null || token.isEmpty) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: const UnauthorizedException(),
        ),
      );
      return;
    }
    options.headers['Authorization'] = 'Bearer $token';
    if (!options.headers.containsKey('Accept')) {
      options.headers['Accept'] = Headers.jsonContentType;
    }
    handler.next(options);
  }

  @override
  Future<Health> health() {
    return _guard(() async {
      final response = await _dio.get<Object?>('/api/health');
      return Health.fromJson(_requireMap(_decodeData(response.data)));
    });
  }

  @override
  Future<DischargeResult> discharge(String summary) {
    return _guard(() async {
      final output = await _postFlow('/api/v1/discharge', <String, dynamic>{
        'input_value': summary,
      });
      return DischargeResult.fromJson(_requireMap(output));
    });
  }

  @override
  Future<CheckinResult> checkin({
    required String patientId,
    required String message,
  }) {
    return _guard(() async {
      final output = await _postFlow('/api/v1/checkins', <String, dynamic>{
        'input_value': jsonEncode(<String, dynamic>{
          'patient_id': patientId,
          'message': message,
        }),
      });
      return CheckinResult.fromJson(_requireMap(output));
    });
  }

  @override
  Future<PlanDraft> draftPlan({
    required String patientId,
    required String followupDate,
    required String hotline,
    required DischargeResult f1ScoredOutput,
  }) {
    return _guard(() async {
      final output = await _postFlow('/api/v1/plans/draft', <String, dynamic>{
        'patient_id': patientId,
        'followup_date': followupDate,
        'hotline': hotline,
        'f1_scored_output': f1ScoredOutput.toF1ScoredOutput(),
      });
      return PlanDraft.fromJson(_requireMap(output));
    });
  }

  @override
  Future<ReviewJob> startReview({required String draftJson}) {
    return _guard(() async {
      final response = await _dio.post<Object?>(
        '/api/v1/reviews',
        data: <String, dynamic>{'draft': draftJson},
      );
      return ReviewJob.fromJson(_responseMap(response.data));
    });
  }

  @override
  Future<void> resumeReview({
    required String jobId,
    required String requestId,
    required String actionId,
    required String actor,
    String reviewerNote = '',
  }) {
    return _guard(() async {
      await _dio.post<Object?>(
        '/api/v1/reviews/${Uri.encodeComponent(jobId)}/resume',
        data: <String, dynamic>{
          'request_id': requestId,
          'action_id': actionId,
          'actor': actor,
          'reviewer_note': reviewerNote,
        },
      );
    });
  }

  @override
  Future<AskAnswer> ask({required String patientId, required String query}) {
    return _guard(() async {
      final output = await _postFlow('/api/v1/answers', <String, dynamic>{
        'patient_id': patientId,
        'query': query,
      });
      final text = output is String
          ? output
          : output == null
          ? ''
          : jsonEncode(output);
      if (text.trim().isEmpty) {
        throw const InvalidResponseException();
      }
      return AskAnswer.fromText(text);
    });
  }

  @override
  Future<PlansResponse> listPlans() {
    return _guard(() async {
      final response = await _dio.get<Object?>('/api/v1/plans');
      return PlansResponse.fromJson(_requireMap(_decodeData(response.data)));
    });
  }

  @override
  Future<ApprovedPlanRecord> getPlan(String patientId) {
    return _guard(() async {
      final response = await _dio.get<Object?>(
        '/api/v1/plans/${Uri.encodeComponent(patientId)}',
      );
      final data = _requireMap(_decodeData(response.data));
      // Live shape: {"patientId": "...", "plans": [{...}]} — a filtered list,
      // not a single record (verified 2026-10-23).
      final plans = data['plans'];
      if (plans is List) {
        if (plans.isEmpty) {
          throw const NotFoundException();
        }
        return ApprovedPlanRecord.fromJson(_requireMap(plans.first));
      }
      if (plans is Map) {
        return ApprovedPlanRecord.fromJson(_requireMap(plans));
      }
      return ApprovedPlanRecord.fromJson(data);
    });
  }

  Future<Object?> _postFlow(String path, Map<String, dynamic> body) async {
    final response = await _dio.post<Object?>(path, data: body);
    final envelope = _asMapOrNull(_decodeData(response.data));
    if (envelope == null) {
      throw const InvalidResponseException();
    }
    final output = envelope['outputText'] ?? envelope['output_text'];
    if (output == null) {
      throw const InvalidResponseException();
    }
    if (output is String) {
      final trimmed = output.trim();
      if (trimmed.isEmpty) {
        throw const InvalidResponseException();
      }
      return _decodeData(trimmed);
    }
    return output;
  }

  Map<String, dynamic> _responseMap(Object? data) {
    final map = _asMapOrNull(_decodeData(data));
    if (map == null) {
      throw const InvalidResponseException();
    }
    if (map.containsKey('jobId') || map.containsKey('job_id')) {
      return map;
    }
    final output = map['outputText'] ?? map['output_text'];
    if (output is String) {
      final nested = _asMapOrNull(_decodeData(output));
      if (nested != null) {
        return nested;
      }
    }
    return map;
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ApiException {
      rethrow;
    } on DioException catch (error) {
      final inner = error.error;
      if (inner is ApiException) {
        throw inner;
      }
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.transformTimeout:
        case DioExceptionType.connectionError:
        case DioExceptionType.badCertificate:
          throw const NetworkException();
        case DioExceptionType.badResponse:
          final response = error.response;
          if (response == null) {
            throw const NetworkException();
          }
          throw apiExceptionForStatus(
            response.statusCode ?? 0,
            _bodyString(response.data),
          );
        case DioExceptionType.cancel:
          throw const UnexpectedApiException('Permintaan dibatalkan.');
        case DioExceptionType.unknown:
          if (inner is FormatException) {
            throw const InvalidResponseException();
          }
          throw const NetworkException();
      }
    } on FormatException {
      throw const InvalidResponseException();
    }
  }
}

String _normalizeBaseUrl(String value) {
  var normalized = value.trim();
  while (normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  return normalized;
}

Object? _decodeData(Object? data) {
  if (data is String) {
    final trimmed = data.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(trimmed);
    } on FormatException {
      return data;
    }
  }
  return data;
}

Map<String, dynamic> _requireMap(Object? value) {
  final map = _asMapOrNull(value);
  if (map == null) {
    throw const InvalidResponseException();
  }
  return map;
}

Map<String, dynamic>? _asMapOrNull(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return null;
}

String _bodyString(Object? data) {
  if (data == null) {
    return '';
  }
  if (data is String) {
    return data;
  }
  try {
    return jsonEncode(data);
  } on Object {
    return data.toString();
  }
}
