import 'dart:convert';

/// Base type for every failure surfaced by the SynCare API layer.
sealed class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

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

class StreamUnavailableException extends ApiException {
  const StreamUnavailableException([
    super.message = 'Aliran peristiwa tidak tersedia. Coba lagi.',
  ]) : super(statusCode: 502);
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

/// Maps an HTTP status code and raw body to the matching [ApiException].
ApiException apiExceptionForStatus(int statusCode, String body) {
  final payload = _decodePayload(body);
  final error = _stringField(payload, 'error');
  final message = _stringField(payload, 'message');
  final failure = payload?['error'];
  if (statusCode == 409 && failure is Map<String, dynamic>) {
    switch (failure['code']) {
      case 'version_conflict':
        return const VersionConflictException();
      case 'idempotency_conflict':
        return const IdempotencyConflictException();
      case 'booking_schedule_conflict':
        return const BookingScheduleConflictException();
    }
  }

  switch (statusCode) {
    case 401:
      return UnauthorizedException(message ?? 'Sesi tidak valid.');
    case 403:
      if (error != 'read_only_mode') return const ForbiddenException();
      return ReadOnlyException(
        message ?? 'Server sedang dalam mode baca-saja.',
      );
    case 404:
      return NotFoundException(message ?? 'Data tidak ditemukan.');
    case 422:
      return ValidationException(message ?? 'Data tidak valid.');
    case 502:
      return StreamUnavailableException(
        message ?? 'Aliran peristiwa tidak tersedia. Coba lagi.',
      );
    case 503:
      final reason = error ?? '';
      if (reason.contains('langflow_unreachable') ||
          reason.contains('langflow_timeout')) {
        return EngineWarmingException(
          message ?? 'Mesin sedang disiapkan. Coba lagi sebentar lagi.',
        );
      }
      if (reason.contains('auth_not_configured')) {
        return ServerConfigException(
          message ?? error ?? 'Konfigurasi server belum lengkap.',
        );
      }
      return UnexpectedApiException(
        message ?? error ?? 'Layanan sementara tidak tersedia.',
        statusCode: statusCode,
      );
    default:
      return UnexpectedApiException(
        message ?? error ?? 'Terjadi kesalahan (HTTP $statusCode).',
        statusCode: statusCode,
      );
  }
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
