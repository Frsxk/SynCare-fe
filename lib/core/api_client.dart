import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/approved_plan.dart';
import '../models/ask_answer.dart';
import '../models/checkin_result.dart';
import '../models/discharge_result.dart';
import '../models/health.dart';
import '../models/plan_draft.dart';
import '../models/review_job.dart';
import '../models/patient.dart';
import '../models/checkin_record.dart';
import '../models/homecare.dart';
import '../models/escalation.dart';
import '../models/verified_care_plan.dart';
import 'api_exception.dart';
import 'config.dart';

/// The SynCare backend surface used by the app.
abstract class SyncareApi {
  Future<VerifiedPlanPage> listVerifiedPlans(
    String patientId, {
    String? cursor,
  });
  Future<EscalationPage> listEscalations(String patientId, {String? cursor});
  Future<Escalation> getEscalation(String alertId, {String? cursor});
  Future<EmergencyRequestResult> requestEmergency({
    required String patientId,
    required String reason,
    required String requestKey,
  });
  Future<ServicePage> listHomecareServices({String? cursor});
  Future<BookingPage> listBookings(String patientId, {String? cursor});
  Future<Booking> getBooking(String bookingId);
  Future<Booking> cancelBooking({
    required String bookingId,
    required int expectedVersion,
    required String reason,
    required String requestKey,
  });
  Future<Booking> requestBooking({
    required String patientId,
    required BookingInput input,
    required String requestKey,
  });
  Future<CheckinRecord> submitCheckin({
    required String patientId,
    required String message,
    required String requestKey,
  });
  Future<CheckinRecord> getCheckin(String checkinId);
  Future<CheckinPage> listCheckins(String patientId, {String? cursor});
  Future<EmergencyGuidance> getEmergencyGuidance();
  Future<PatientOverview> getPatientOverview(String patientId);
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
  Future<QuestionOutcome> ask({
    required String patientId,
    required String query,
  });
  Future<PlansResponse> listPlans();
  Future<ApprovedPlanRecord> getPlan(String patientId);
}

/// Dio-backed implementation of [SyncareApi].
class ApiClient implements SyncareApi {
  @override
  Future<VerifiedPlanPage> listVerifiedPlans(
    String patientId, {
    String? cursor,
  }) => _guard(() async {
    final response = await _dio.get<Object?>(
      '/api/v1/patients/${Uri.encodeComponent(patientId)}/care-plans',
      queryParameters: {'limit': 20, 'cursor': ?cursor},
    );
    final page = VerifiedPlanPage.fromJson(_decodeData(response.data));
    if (page.plans.any((p) => p.record.patientId != patientId)) {
      throw const InvalidResponseException();
    }
    return page;
  });
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

  @override
  Future<EscalationPage> listEscalations(String patientId, {String? cursor}) =>
      _guard(() async {
        final response = await _dio.get<Object?>(
          '/api/v1/patients/${Uri.encodeComponent(patientId)}/alerts',
          queryParameters: {'limit': 20, 'cursor': ?cursor},
          options: Options(headers: {'X-SynCare-Alert-Sources': 'all'}),
        );
        final page = EscalationPage.fromJson(_decodeData(response.data));
        if (page.alerts.any((a) => a.patientId != patientId)) {
          throw const InvalidResponseException();
        }
        return page;
      });
  @override
  Future<Escalation> getEscalation(String alertId, {String? cursor}) =>
      _guard(() async {
        final response = await _dio.get<Object?>(
          '/api/v1/alerts/${Uri.encodeComponent(alertId)}',
          queryParameters: {'limit': 20, 'cursor': ?cursor},
        );
        final alert = Escalation.fromJson(
          _requireMap(_decodeData(response.data))['data'],
          detail: true,
        );
        if (alert.id != alertId) throw const InvalidResponseException();
        return alert;
      });
  @override
  Future<EmergencyRequestResult> requestEmergency({
    required String patientId,
    required String reason,
    required String requestKey,
  }) => _guard(() async {
    final response = await _dio.post<Object?>(
      '/api/v1/patients/${Uri.encodeComponent(patientId)}/emergencies',
      data: {'reason': reason},
      options: Options(headers: {'Idempotency-Key': requestKey}),
    );
    final data = _requireMap(_decodeData(response.data))['data'];
    return EmergencyRequestResult.fromJson(data, patientId: patientId);
  });
  @override
  Future<BookingPage> listBookings(String patientId, {String? cursor}) =>
      _guard(() async {
        final response = await _dio.get<Object?>(
          '/api/v1/patients/${Uri.encodeComponent(patientId)}/bookings',
          queryParameters: {'limit': 20, 'cursor': ?cursor},
        );
        final page = BookingPage.fromJson(_decodeData(response.data));
        if (page.bookings.any((b) => b.patientId != patientId)) {
          throw const InvalidResponseException();
        }
        return page;
      });
  @override
  Future<Booking> getBooking(String bookingId) => _guard(() async {
    final response = await _dio.get<Object?>(
      '/api/v1/bookings/${Uri.encodeComponent(bookingId)}',
    );
    final booking = Booking.fromJson(
      _requireMap(_decodeData(response.data))['data'],
    );
    if (booking.id != bookingId) {
      throw const InvalidResponseException();
    }
    return booking;
  });
  @override
  Future<Booking> cancelBooking({
    required String bookingId,
    required int expectedVersion,
    required String reason,
    required String requestKey,
  }) => _guard(() async {
    final response = await _dio.post<Object?>(
      '/api/v1/bookings/${Uri.encodeComponent(bookingId)}/transitions',
      data: {
        'expectedVersion': expectedVersion,
        'toStatus': 'Cancelled',
        'reason': reason,
      },
      options: Options(headers: {'Idempotency-Key': requestKey}),
    );
    final booking = Booking.fromJson(
      _requireMap(_requireMap(_decodeData(response.data))['data'])['resource'],
    );
    if (booking.id != bookingId || booking.status != BookingStatus.cancelled) {
      throw const InvalidResponseException();
    }
    return booking;
  });

  @override
  Future<ServicePage> listHomecareServices({String? cursor}) =>
      _guard(() async {
        final response = await _dio.get<Object?>(
          '/api/v1/homecare/services',
          queryParameters: {'limit': 20, 'cursor': ?cursor},
        );
        return ServicePage.fromJson(_decodeData(response.data));
      });
  @override
  Future<Booking> requestBooking({
    required String patientId,
    required BookingInput input,
    required String requestKey,
  }) => _guard(() async {
    final response = await _dio.post<Object?>(
      '/api/v1/patients/${Uri.encodeComponent(patientId)}/bookings',
      data: input.toJson(),
      options: Options(headers: {'Idempotency-Key': requestKey}),
    );
    final booking = Booking.fromJson(
      _requireMap(_requireMap(_decodeData(response.data))['data'])['resource'],
    );
    if (booking.patientId != patientId ||
        booking.service.id != input.serviceId) {
      throw const InvalidResponseException();
    }
    return booking;
  });

  @override
  Future<CheckinRecord> submitCheckin({
    required String patientId,
    required String message,
    required String requestKey,
  }) => _guard(() async {
    final response = await _dio.post<Object?>(
      '/api/v1/patients/${Uri.encodeComponent(patientId)}/checkins',
      data: {'message': message},
      options: Options(headers: {'Idempotency-Key': requestKey}),
    );
    final record = CheckinRecord.fromJson(
      _requireMap(_requireMap(_decodeData(response.data))['data'])['resource'],
    );
    if (record.patientId != patientId) throw const InvalidResponseException();
    return record;
  });
  @override
  Future<CheckinRecord> getCheckin(String checkinId) => _guard(() async {
    final response = await _dio.get<Object?>(
      '/api/v1/checkins/${Uri.encodeComponent(checkinId)}',
    );
    final record = CheckinRecord.fromJson(
      _requireMap(_decodeData(response.data))['data'],
    );
    if (record.id != checkinId) throw const InvalidResponseException();
    return record;
  });
  @override
  Future<CheckinPage> listCheckins(String patientId, {String? cursor}) =>
      _guard(() async {
        final response = await _dio.get<Object?>(
          '/api/v1/patients/${Uri.encodeComponent(patientId)}/checkins',
          queryParameters: {'limit': 20, 'cursor': ?cursor},
        );
        final page = CheckinPage.fromJson(_decodeData(response.data));
        if (page.records.any((r) => r.patientId != patientId)) {
          throw const InvalidResponseException();
        }
        return page;
      });
  @override
  Future<EmergencyGuidance> getEmergencyGuidance() => _guard(() async {
    final response = await _dio.get<Object?>('/api/v1/emergency-guidance');
    return EmergencyGuidance.fromJson(
      _requireMap(_decodeData(response.data))['data'],
    );
  });

  @override
  Future<PatientOverview> getPatientOverview(String patientId) =>
      _guard(() async {
        final response = await _dio.get<Object?>(
          '/api/v1/patients/${Uri.encodeComponent(patientId)}/overview',
        );
        final envelope = _requireMap(_decodeData(response.data));
        final overview = PatientOverview.fromJson(envelope['data']);
        if (overview.profile.id != patientId) {
          throw const InvalidResponseException();
        }
        return overview;
      });

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
  Future<QuestionOutcome> ask({
    required String patientId,
    required String query,
  }) {
    return _guard(() async {
      final response = await _dio.post<Object?>(
        '/api/v1/patients/${Uri.encodeComponent(patientId)}/questions',
        data: {'query': query},
      );
      return QuestionOutcome.fromJson(
        _requireMap(_decodeData(response.data))['data'],
        patientId,
      );
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
      // Live shape: {"patientId": "...", "plans": [{...}]}, a filtered list,
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
