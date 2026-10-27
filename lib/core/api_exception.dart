import 'dart:convert';

/// Base type for every failure surfaced by the SynCare API layer.
sealed class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.code,
    this.requestId,
    this.retryable,
  });

  final String message;
  final int? statusCode;

  /// Closed domain code when the server supplied one.
  final String? code;

  /// Correlation id from a domain envelope; never rendered as patient copy.
  final String? requestId;

  /// Server retry hint. It never authorizes an automatic resend.
  final bool? retryable;

  @override
  String toString() => message;
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException([super.message = 'Sesi tidak valid.'])
    : super(statusCode: 401);
}

class ReadOnlyException extends ApiException {
  const ReadOnlyException([
    super.message = 'Server sedang dalam mode baca-saja.',
  ]) : super(statusCode: 403);
}

class ForbiddenException extends ApiException {
  const ForbiddenException()
    : super('Anda tidak memiliki akses untuk tindakan ini.', statusCode: 403);
}

class NotFoundException extends ApiException {
  const NotFoundException([super.message = 'Data tidak ditemukan.'])
    : super(statusCode: 404);
}

class ValidationException extends ApiException {
  const ValidationException(super.message) : super(statusCode: 422);
}

class VersionConflictException extends ApiException {
  const VersionConflictException()
    : super(
        'Data telah berubah. Muat data terbaru sebelum melanjutkan.',
        statusCode: 409,
      );
}

class IdempotencyConflictException extends ApiException {
  const IdempotencyConflictException()
    : super(
        'Identitas permintaan telah digunakan untuk data berbeda. Periksa status terbaru.',
        statusCode: 409,
      );
}

class BookingScheduleConflictException extends ApiException {
  const BookingScheduleConflictException()
    : super(
        'Jadwal petugas bertabrakan dengan kunjungan lain. Pilih waktu atau petugas lain.',
        statusCode: 409,
      );
}

class RateLimitedException extends ApiException {
  const RateLimitedException({
    String message = 'Terlalu banyak permintaan. Coba kembali nanti.',
    String? requestId,
    bool? retryable = false,
  }) : super(
         message,
         statusCode: 429,
         code: 'rate_limited',
         requestId: requestId,
         retryable: retryable,
       );
}

/// A mutation may have reached the dependency, so its result is not known.
/// Recovery must reconcile the original request, never blindly resend it.
class OutcomeUnknownException extends ApiException {
  const OutcomeUnknownException({
    String message =
        'Hasil permintaan belum dapat dipastikan. Periksa status sebelum mengirim ulang.',
    String? requestId,
    bool? retryable = false,
  }) : super(
         message,
         statusCode: 502,
         code: 'outcome_unknown',
         requestId: requestId,
         retryable: retryable,
       );
}

class InvalidFlowOutputException extends ApiException {
  const InvalidFlowOutputException({
    String message = 'Hasil pemrosesan tidak dapat ditampilkan.',
    String? requestId,
    bool? retryable = false,
  }) : super(
         message,
         statusCode: 502,
         code: 'invalid_flow_output',
         requestId: requestId,
         retryable: retryable,
       );
}

class DependencyUnavailableException extends ApiException {
  const DependencyUnavailableException({
    String message = 'Layanan belum tersedia. Coba muat kembali.',
    String? requestId,
    bool? retryable = true,
  }) : super(
         message,
         statusCode: 503,
         code: 'dependency_unavailable',
         requestId: requestId,
         retryable: retryable,
       );
}

class EmergencyGuidanceUnavailableException extends ApiException {
  const EmergencyGuidanceUnavailableException({
    String message = 'Informasi layanan darurat belum tersedia.',
    String? requestId,
    bool? retryable = false,
  }) : super(
         message,
         statusCode: 503,
         code: 'emergency_guidance_unavailable',
         requestId: requestId,
         retryable: retryable,
       );
}

class ProcessingFailedException extends ApiException {
  const ProcessingFailedException({
    String message = 'Proses belum berhasil diselesaikan.',
    String? requestId,
    bool? retryable = false,
  }) : super(
         message,
         statusCode: 500,
         code: 'processing_failed',
         requestId: requestId,
         retryable: retryable,
       );
}

class StreamUnavailableException extends ApiException {
  const StreamUnavailableException([
    super.message = 'Aliran peristiwa tidak tersedia. Coba lagi.',
  ]) : super(statusCode: 502, code: 'events_unavailable');
}

class EngineWarmingException extends ApiException {
  const EngineWarmingException([
    super.message = 'Mesin sedang disiapkan. Coba lagi sebentar lagi.',
  ]) : super(statusCode: 503);
}

class ServerConfigException extends ApiException {
  const ServerConfigException(super.message) : super(statusCode: 503);
}

class NetworkException extends ApiException {
  const NetworkException([super.message = 'Tidak dapat terhubung ke server.']);
}

class UnexpectedApiException extends ApiException {
  const UnexpectedApiException(super.message, {super.statusCode});
}

class InvalidResponseException extends ApiException {
  const InvalidResponseException([
    super.message = 'Respons server tidak dapat dibaca.',
  ]);
}

const String _genericFailure = 'Terjadi kesalahan. Coba lagi nanti.';

/// Maps an HTTP status code and raw body to the matching [ApiException].
///
/// The domain envelope (`error.code`, `error.message`, `error.requestId`,
/// `error.retryable`) wins over the HTTP status. Legacy flat string codes are
/// retained only where an older route still serves them. An envelope without a
/// usable string code keeps the closed status mapping instead of swallowing it.
/// Unknown codes and malformed bodies never expose the server-supplied message.
ApiException apiExceptionForStatus(int statusCode, String body) {
  final payload = _decodePayload(body);
  final failure = _nestedFailure(payload);
  final domainCode = failure == null ? null : _stringField(failure, 'code');
  if (failure != null && domainCode != null) {
    return _domainException(statusCode, domainCode, failure);
  }

  final legacyCode = _stringField(payload, 'error');
  if (legacyCode != null) {
    final legacy = _legacyException(
      statusCode,
      legacyCode,
      _stringField(payload, 'message'),
    );
    if (legacy != null) {
      return legacy;
    }
  }
  return _statusFallback(statusCode);
}

ApiException _domainException(
  int statusCode,
  String code,
  Map<String, dynamic> failure,
) {
  final message = _stringField(failure, 'message');
  final requestId = _stringField(failure, 'requestId');
  final retryable = failure['retryable'];
  final retryHint = retryable is bool ? retryable : null;

  switch (code) {
    case 'unauthenticated':
      return UnauthorizedException(message ?? 'Sesi tidak valid.');
    case 'forbidden':
      return const ForbiddenException();
    case 'read_only_mode':
      return ReadOnlyException(message ?? 'Server sedang dalam mode baca-saja.');
    case 'not_found':
      return NotFoundException(message ?? 'Data tidak ditemukan.');
    case 'validation_failed':
      return ValidationException(
        message ?? 'Periksa kembali data yang dikirim.',
      );
    case 'version_conflict':
      return const VersionConflictException();
    case 'idempotency_conflict':
      return const IdempotencyConflictException();
    case 'booking_schedule_conflict':
      return const BookingScheduleConflictException();
    case 'rate_limited':
      return RateLimitedException(
        message: message ?? 'Terlalu banyak permintaan. Coba kembali nanti.',
        requestId: requestId,
        retryable: retryHint ?? false,
      );
    case 'outcome_unknown':
      return OutcomeUnknownException(
        message:
            message ??
            'Hasil permintaan belum dapat dipastikan. Periksa status sebelum mengirim ulang.',
        requestId: requestId,
        retryable: retryHint ?? false,
      );
    case 'invalid_flow_output':
      return InvalidFlowOutputException(
        message: message ?? 'Hasil pemrosesan tidak dapat ditampilkan.',
        requestId: requestId,
        retryable: retryHint ?? false,
      );
    case 'dependency_unavailable':
      return DependencyUnavailableException(
        message: message ?? 'Layanan belum tersedia. Coba muat kembali.',
        requestId: requestId,
        retryable: retryHint ?? true,
      );
    case 'emergency_guidance_unavailable':
      return EmergencyGuidanceUnavailableException(
        message: message ?? 'Informasi layanan darurat belum tersedia.',
        requestId: requestId,
        retryable: retryHint ?? false,
      );
    case 'processing_failed':
      return ProcessingFailedException(
        message: message ?? 'Proses belum berhasil diselesaikan.',
        requestId: requestId,
        retryable: retryHint ?? false,
      );
    default:
      return UnexpectedApiException(_genericFailure, statusCode: statusCode);
  }
}

ApiException? _legacyException(
  int statusCode,
  String code,
  String? message,
) {
  if (statusCode == 401 &&
      (code == 'unauthorized' || code == 'unauthenticated')) {
    return UnauthorizedException(message ?? 'Sesi tidak valid.');
  }
  if (statusCode == 403 && code == 'read_only_mode') {
    return ReadOnlyException(message ?? 'Server sedang dalam mode baca-saja.');
  }
  if (statusCode == 403 && code == 'forbidden') {
    return const ForbiddenException();
  }
  if (statusCode == 404 && code == 'not_found') {
    return NotFoundException(message ?? 'Data tidak ditemukan.');
  }
  if (statusCode == 422 &&
      (code == 'validation' || code == 'validation_failed')) {
    return ValidationException(
      message ?? 'Periksa kembali data yang dikirim.',
    );
  }
  if (statusCode == 409) {
    switch (code) {
      case 'version_conflict':
        return const VersionConflictException();
      case 'idempotency_conflict':
        return const IdempotencyConflictException();
      case 'booking_schedule_conflict':
        return const BookingScheduleConflictException();
    }
  }
  if (statusCode == 429 && code == 'rate_limited') {
    return RateLimitedException(
      message: message ?? 'Terlalu banyak permintaan. Coba kembali nanti.',
    );
  }
  if (statusCode == 502 &&
      (code == 'events_unavailable' || code == 'stream_unavailable')) {
    return StreamUnavailableException(
      message ?? 'Aliran peristiwa tidak tersedia. Coba lagi.',
    );
  }
  if (statusCode == 502 && code == 'langflow_http_error') {
    return const InvalidFlowOutputException();
  }
  if (statusCode == 503 &&
      (code == 'langflow_unreachable' || code == 'langflow_timeout')) {
    return EngineWarmingException(
      message ?? 'Mesin sedang disiapkan. Coba lagi sebentar lagi.',
    );
  }
  if (statusCode == 503 && code == 'auth_not_configured') {
    return ServerConfigException(message ?? code);
  }
  if (statusCode == 500 && code == 'internal') {
    return const ProcessingFailedException();
  }
  return null;
}

ApiException _statusFallback(int statusCode) {
  switch (statusCode) {
    case 401:
      return const UnauthorizedException();
    case 403:
      return const ForbiddenException();
    case 404:
      return const NotFoundException();
    case 422:
      return const ValidationException('Periksa kembali data yang dikirim.');
    case 429:
      return const RateLimitedException();
    case 503:
      return const DependencyUnavailableException();
    default:
      return UnexpectedApiException(_genericFailure, statusCode: statusCode);
  }
}

Map<String, dynamic>? _nestedFailure(Map<String, dynamic>? payload) {
  final value = payload?['error'];
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return null;
}

Map<String, dynamic>? _decodePayload(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
  } on FormatException {
    return null;
  }
  return null;
}

String? _stringField(Map<String, dynamic>? payload, String key) {
  final value = payload?[key];
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  return null;
}
