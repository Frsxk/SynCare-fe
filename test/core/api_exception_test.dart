import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:syncare_flutter/core/api_exception.dart';

import '../helpers/error_fixture.dart';

void main() {
  group('nested domain envelope', () {
    test('401 unauthenticated keeps the public session message', () {
      final error = apiExceptionForStatus(
        401,
        nestedErrorBody(
          'unauthenticated',
          message: 'Silakan masuk kembali.',
          requestId: 'req-auth',
        ),
      );
      expect(error, isA<UnauthorizedException>());
      expect(error.message, 'Silakan masuk kembali.');
      expect(error.statusCode, 401);
    });

    test('403 forbidden is distinct from nested read-only compatibility', () {
      expect(
        apiExceptionForStatus(
          403,
          nestedErrorBody('forbidden', message: 'Rincian internal.'),
        ),
        isA<ForbiddenException>(),
      );
      expect(
        apiExceptionForStatus(
          403,
          nestedErrorBody('read_only_mode', message: 'Mode baca.'),
        ),
        isA<ReadOnlyException>(),
      );
    });

    test('404 and 422 use the public domain message', () {
      final missing = apiExceptionForStatus(
        404,
        nestedErrorBody('not_found', message: 'Data tidak ditemukan.'),
      );
      expect(missing, isA<NotFoundException>());
      expect(missing.message, 'Data tidak ditemukan.');

      final invalid = apiExceptionForStatus(
        422,
        nestedErrorBody(
          'validation_failed',
          message: 'Periksa kembali data yang dikirim.',
        ),
      );
      expect(invalid, isA<ValidationException>());
      expect(invalid.message, 'Periksa kembali data yang dikirim.');
    });

    test('all three 409 variants select their typed recovery', () {
      expect(
        apiExceptionForStatus(
          409,
          nestedErrorBody('version_conflict', message: 'Versi berubah.'),
        ),
        isA<VersionConflictException>(),
      );
      expect(
        apiExceptionForStatus(
          409,
          nestedErrorBody('idempotency_conflict', message: 'Kunci dipakai.'),
        ),
        isA<IdempotencyConflictException>(),
      );
      expect(
        apiExceptionForStatus(
          409,
          nestedErrorBody(
            'booking_schedule_conflict',
            message: 'Jadwal bertabrakan.',
          ),
        ),
        isA<BookingScheduleConflictException>(),
      );
    });

    test('429 rate_limited is typed and not a generic server error', () {
      final error = apiExceptionForStatus(
        429,
        nestedErrorBody(
          'rate_limited',
          message: 'Terlalu banyak percobaan masuk. Coba kembali nanti.',
          requestId: 'req-rate',
        ),
      );
      expect(error, isA<RateLimitedException>());
      expect(error.statusCode, 429);
      expect(error.message, contains('Terlalu banyak'));
    });

    test('502 outcome_unknown carries requestId/retryable and is not SSE', () {
      final error = apiExceptionForStatus(
        502,
        nestedErrorBody(
          'outcome_unknown',
          message:
              'Hasil permintaan belum dapat dipastikan. Periksa status sebelum mengirim ulang.',
          requestId: 'req-outcome',
          retryable: false,
        ),
      );
      expect(error, isA<OutcomeUnknownException>());
      expect(error, isNot(isA<StreamUnavailableException>()));
      expect(error.statusCode, 502);
      expect(error.requestId, 'req-outcome');
      expect(error.retryable, isFalse);
      expect(error.message, contains('belum dapat dipastikan'));
    });

    test('502 invalid_flow_output is a display failure, not SSE', () {
      final error = apiExceptionForStatus(
        502,
        nestedErrorBody(
          'invalid_flow_output',
          message: 'Hasil pemrosesan tidak dapat ditampilkan.',
          requestId: 'req-flow',
        ),
      );
      expect(error, isA<InvalidFlowOutputException>());
      expect(error, isNot(isA<StreamUnavailableException>()));
      expect(error.statusCode, 502);
      expect(error.requestId, 'req-flow');
    });

    test('503 dependency_unavailable is retryable and not engine warming', () {
      final error = apiExceptionForStatus(
        503,
        nestedErrorBody(
          'dependency_unavailable',
          message: 'Layanan belum tersedia. Coba muat kembali.',
          requestId: 'req-dependency',
          retryable: true,
        ),
      );
      expect(error, isA<DependencyUnavailableException>());
      expect(error, isNot(isA<EngineWarmingException>()));
      expect(error, isNot(isA<UnexpectedApiException>()));
      expect(error.retryable, isTrue);
      expect(error.requestId, 'req-dependency');
    });

    test('503 emergency_guidance_unavailable is its own safe domain error', () {
      final error = apiExceptionForStatus(
        503,
        nestedErrorBody(
          'emergency_guidance_unavailable',
          message: 'Informasi layanan darurat belum tersedia.',
        ),
      );
      expect(error, isA<EmergencyGuidanceUnavailableException>());
      expect(error, isNot(isA<EngineWarmingException>()));
      expect(error.message, contains('layanan darurat'));
    });

    test('500 processing_failed is typed without upstream detail', () {
      final error = apiExceptionForStatus(
        500,
        nestedErrorBody('processing_failed', message: 'Proses gagal.'),
      );
      expect(error, isA<ProcessingFailedException>());
      expect(error.statusCode, 500);
    });
  });

  group('legacy flat envelope compatibility', () {
    test('read_only_mode stays a ReadOnlyException', () {
      final error = apiExceptionForStatus(
        403,
        legacyErrorBody('read_only_mode', message: 'Read-only.'),
      );
      expect(error, isA<ReadOnlyException>());
      expect(error.message, 'Read-only.');
    });

    test('legacy 502 events_unavailable remains the SSE exception', () {
      final error = apiExceptionForStatus(
        502,
        legacyErrorBody('events_unavailable', message: 'mati'),
      );
      expect(error, isA<StreamUnavailableException>());
      expect(error.message, 'mati');
    });

    test('legacy 502 langflow_http_error never becomes an SSE failure', () {
      final error = apiExceptionForStatus(
        502,
        legacyErrorBody('langflow_http_error', message: 'raw upstream body'),
      );
      expect(error, isA<InvalidFlowOutputException>());
      expect(error, isNot(isA<StreamUnavailableException>()));
      expect(error.message, isNot(contains('raw upstream')));
    });

    test('legacy 503 langflow errors keep engine warming copy', () {
      expect(
        apiExceptionForStatus(503, legacyErrorBody('langflow_unreachable')),
        isA<EngineWarmingException>(),
      );
      expect(
        apiExceptionForStatus(503, legacyErrorBody('langflow_timeout')),
        isA<EngineWarmingException>(),
      );
    });

    test('legacy 503 auth_not_configured remains server configuration', () {
      expect(
        apiExceptionForStatus(
          503,
          legacyErrorBody(
            'auth_not_configured',
            message: 'SYNCARE_API_KEY belum diatur.',
          ),
        ),
        isA<ServerConfigException>(),
      );
    });

    test('legacy 401 unauthorized keeps its public message', () {
      final error = apiExceptionForStatus(
        401,
        legacyErrorBody('unauthorized', message: 'Token tidak valid.'),
      );
      expect(error, isA<UnauthorizedException>());
      expect(error.message, 'Token tidak valid.');
    });
  });

  group('malformed or unknown envelopes fail closed', () {
    test('unknown nested code hides even a plausible server message', () {
      final error = apiExceptionForStatus(
        502,
        nestedErrorBody(
          'future_domain_code',
          message: 'RAW upstream token=secret',
          requestId: 'req-unknown',
          retryable: true,
        ),
      );
      expect(error, isA<UnexpectedApiException>());
      expect(error, isNot(isA<StreamUnavailableException>()));
      expect(error.message, isNot(contains('RAW')));
      expect(error.message, isNot(contains('secret')));
    });

    test('malformed nested map uses a closed status fallback', () {
      final noCode = apiExceptionForStatus(
        422,
        jsonEncode(<String, Object?>{
          'error': <String, Object?>{'message': 'raw field diagnostics'},
        }),
      );
      expect(noCode, isA<ValidationException>());
      expect(noCode.message, isNot(contains('raw')));

      final wrongCode = apiExceptionForStatus(
        502,
        jsonEncode(<String, Object?>{
          'error': <String, Object?>{'code': 9, 'message': 'raw body'},
        }),
      );
      expect(wrongCode, isA<UnexpectedApiException>());
      expect(wrongCode.message, isNot(contains('raw body')));
    });

    test('unknown flat code and plain text never leak into patient copy', () {
      final flat = apiExceptionForStatus(
        500,
        legacyErrorBody('future_legacy_code', message: 'RAW stack trace'),
      );
      expect(flat, isA<UnexpectedApiException>());
      expect(flat.message, isNot(contains('RAW')));

      final text = apiExceptionForStatus(502, '<html>upstream failure</html>');
      expect(text, isA<UnexpectedApiException>());
      expect(text.message, isNot(contains('html')));
      expect(text, isNot(isA<StreamUnavailableException>()));
    });

    test('empty bodies still use status-level typed recovery', () {
      expect(apiExceptionForStatus(401, ''), isA<UnauthorizedException>());
      expect(apiExceptionForStatus(403, ''), isA<ForbiddenException>());
      expect(apiExceptionForStatus(404, ''), isA<NotFoundException>());
      expect(apiExceptionForStatus(422, ''), isA<ValidationException>());
      expect(apiExceptionForStatus(429, ''), isA<RateLimitedException>());
      expect(
        apiExceptionForStatus(503, ''),
        isA<DependencyUnavailableException>(),
      );
    });
  });
}
