import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:syncare_flutter/core/api_client.dart';
import 'package:syncare_flutter/core/api_exception.dart';
import 'package:syncare_flutter/models/homecare.dart';
import '../helpers/fakes.dart';
import '../helpers/homecare_fixture.dart';
import '../helpers/booking_lifecycle_fixture.dart';

void main() {
  test(
    'Dio H3/H4 own history/detail/cancel payload and typed409 preserve server authority',
    () async {
      final dio = Dio();
      final client = ApiClient(
        baseUrl: 'http://syncare.test',
        tokenSource: FakeTokenSource('synthetic-session'),
        dio: dio,
      );
      final wire = DioAdapter(dio: dio);
      addTearDown(() => dio.close(force: true));
      wire.onGet(
        '/api/v1/patients/patient-a/bookings',
        (s) => s.reply(200, {
          'data': [lifecycleJson()],
          'nextCursor': null,
          'requestId': 'test',
        }),
        queryParameters: {'limit': 20},
      );
      expect(
        (await client.listBookings('patient-a')).bookings.single.id,
        'booking-a',
      );
      wire.onGet(
        '/api/v1/bookings/booking-a',
        (s) => s.reply(200, {'data': lifecycleJson(), 'requestId': 'test'}),
      );
      expect((await client.getBooking('booking-a')).canCancel, true);
      final body = {
        'expectedVersion': 1,
        'toStatus': 'Cancelled',
        'reason': 'Alasan pasien',
      };
      const key = 'd311d41e-4517-470d-886c-98f92f26500c';
      wire.onPost(
        '/api/v1/bookings/booking-a/transitions',
        (s) => s.reply(409, {
          'error': {
            'code': 'version_conflict',
            'message': 'Data berubah.',
            'requestId': 'test',
            'retryable': false,
          },
        }),
        data: body,
      );
      await expectLater(
        client.cancelBooking(
          bookingId: 'booking-a',
          expectedVersion: 1,
          reason: 'Alasan pasien',
          requestKey: key,
        ),
        throwsA(isA<VersionConflictException>()),
      );
      wire.onPost(
        '/api/v1/bookings/booking-a/transitions',
        (s) => s.reply(200, {
          'data': {
            'resource': lifecycleJson(status: 'Cancelled'),
            'replayed': true,
          },
          'requestId': 'test',
        }),
        data: body,
      );
      expect(
        (await client.cancelBooking(
          bookingId: 'booking-a',
          expectedVersion: 1,
          reason: 'Alasan pasien',
          requestKey: key,
        )).status,
        BookingStatus.cancelled,
      );
    },
  );
  test(
    'Dio H1/H2 carries own route, exact body/key and parses committed booking, denies foreign receipt',
    () async {
      final dio = Dio();
      final adapter = DioAdapter(dio: dio);
      final client = ApiClient(
        baseUrl: 'http://syncare.test',
        tokenSource: FakeTokenSource('synthetic-session'),
        dio: dio,
      );
      addTearDown(() => dio.close(force: true));
      adapter.onGet(
        '/api/v1/homecare/services',
        (s) => s.reply(200, {
          'data': [bookingJson()['service']],
          'nextCursor': null,
          'requestId': 'r',
        }),
        queryParameters: {'limit': 20},
      );
      expect(
        (await client.listHomecareServices()).services.single.id,
        demoService.id,
      );
      String? key;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            key = options.headers['Idempotency-Key'] as String?;
            handler.next(options);
          },
        ),
      );
      adapter.onPost(
        '/api/v1/patients/patient-a/bookings',
        (s) => s.reply(201, {
          'data': {'resource': bookingJson(), 'replayed': false},
          'requestId': 'r',
        }),
        data: bookingInput.toJson(),
      );
      expect(
        (await client.requestBooking(
          patientId: 'patient-a',
          input: bookingInput,
          requestKey: 'b56e6132-7328-45f6-aabc-33250453a8db',
        )).id,
        'booking-a',
      );
      expect(key, 'b56e6132-7328-45f6-aabc-33250453a8db');
      adapter.onPost(
        '/api/v1/patients/patient-a/bookings',
        (s) => s.reply(201, {
          'data': {
            'resource': bookingJson(patientId: 'foreign'),
            'replayed': false,
          },
          'requestId': 'r',
        }),
        data: bookingInput.toJson(),
      );
      await expectLater(
        client.requestBooking(
          patientId: 'patient-a',
          input: bookingInput,
          requestKey: 'b56e6132-7328-45f6-aabc-33250453a8db',
        ),
        throwsA(isA<InvalidResponseException>()),
      );
    },
  );
}
