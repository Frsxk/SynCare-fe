import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:syncare_flutter/core/api_client.dart';
import 'package:syncare_flutter/core/api_exception.dart';
import '../helpers/escalation_fixture.dart';
import '../helpers/fakes.dart';

void main() {
  test('alert history opts into patient-request sources without changing auth', () async {
    final dio = Dio();
    final client = ApiClient(baseUrl: 'http://syncare.test', tokenSource: FakeTokenSource('synthetic-session'), dio: dio);
    final wire = DioAdapter(dio: dio);
    addTearDown(() => dio.close(force: true));
    final captured = <RequestOptions>[];
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) { captured.add(options); handler.next(options); }));
    wire.onGet('/api/v1/patients/patient-a/alerts', (server) => server.reply(200, {'data': <Object>[], 'nextCursor': null}), queryParameters: {'limit': 20});
    await client.listEscalations('patient-a');
    expect(captured.single.headers['X-SynCare-Alert-Sources'], 'all');
    expect(captured.single.headers['Authorization'], 'Bearer synthetic-session');
  });

  test(
    'Dio emergency POST uses own patient route, exact reason body, bearer auth and UUID idempotency header',
    () async {
      final dio = Dio();
      final client = ApiClient(
        baseUrl: 'http://syncare.test',
        tokenSource: FakeTokenSource('synthetic-session'),
        dio: dio,
      );
      final wire = DioAdapter(dio: dio);
      addTearDown(() => dio.close(force: true));
      final captured = <RequestOptions>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured.add(options);
            handler.next(options);
          },
        ),
      );
      const key = '0f5f65ee-5c04-4f6e-8b2a-4a6bbf6a1c11';
      wire.onPost(
        '/api/v1/patients/patient-a/emergencies',
        (s) => s.reply(201, {
          'data': {
            'resource': patientRequestJson(reason: 'Sesak berat sejak tadi.'),
            'replayed': false,
          },
          'requestId': 'req-emergency',
        }),
        data: {'reason': 'Sesak berat sejak tadi.'},
      );
      final result = await client.requestEmergency(
        patientId: 'patient-a',
        reason: 'Sesak berat sejak tadi.',
        requestKey: key,
      );
      expect(result.alert.id, 'alert-request-a');
      expect(result.alert.isPatientRequest, isTrue);
      expect(result.alert.requestId, 'request-a');
      expect(result.alert.reportId, isNull);
      expect(result.alert.attemptId, isNull);
      expect(result.replayed, isFalse);
      expect(captured, hasLength(1));
      expect(captured.single.method, 'POST');
      expect(
        captured.single.uri.path,
        '/api/v1/patients/patient-a/emergencies',
      );
      expect(captured.single.headers['Idempotency-Key'], key);
      expect(captured.single.headers['Authorization'], 'Bearer synthetic-session');
      expect(captured.single.data, {'reason': 'Sesak berat sejak tadi.'});
    },
  );

  test('replayed 201 is parsed without duplicating the request', () async {
    final dio = Dio();
    final client = ApiClient(
      baseUrl: 'http://syncare.test',
      tokenSource: FakeTokenSource('synthetic-session'),
      dio: dio,
    );
    final wire = DioAdapter(dio: dio);
    addTearDown(() => dio.close(force: true));
    wire.onPost(
      '/api/v1/patients/patient-a/emergencies',
      (s) => s.reply(201, {
        'data': {'resource': patientRequestJson(), 'replayed': true},
        'requestId': 'req-emergency',
      }),
      data: {'reason': 'Pasien meminta bantuan segera.'},
    );
    final result = await client.requestEmergency(
      patientId: 'patient-a',
      reason: 'Pasien meminta bantuan segera.',
      requestKey: '0f5f65ee-5c04-4f6e-8b2a-4a6bbf6a1c11',
    );
    expect(result.replayed, isTrue);
  });

  test(
    'definitive 422 is typed validation; malformed or foreign 201 is invalid response',
    () async {
      final dio = Dio();
      final client = ApiClient(
        baseUrl: 'http://syncare.test',
        tokenSource: FakeTokenSource('synthetic-session'),
        dio: dio,
      );
      final wire = DioAdapter(dio: dio);
      addTearDown(() => dio.close(force: true));
      wire.onPost(
        '/api/v1/patients/patient-a/emergencies',
        (s) => s.reply(422, {
          'error': {
            'code': 'validation_failed',
            'message': 'Alasan wajib diisi.',
            'requestId': 'req-emergency',
            'retryable': false,
          },
        }),
        data: {'reason': 'x'},
      );
      await expectLater(
        client.requestEmergency(
          patientId: 'patient-a',
          reason: 'x',
          requestKey: '0f5f65ee-5c04-4f6e-8b2a-4a6bbf6a1c11',
        ),
        throwsA(isA<ValidationException>()),
      );
      for (final resource in [
        escalationJson(),
        patientRequestJson(patientId: 'foreign'),
      ]) {
        wire.onPost(
          '/api/v1/patients/patient-a/emergencies',
          (s) => s.reply(201, {
            'data': {'resource': resource, 'replayed': false},
            'requestId': 'req-emergency',
          }),
          data: {'reason': 'x'},
        );
        await expectLater(
          client.requestEmergency(
            patientId: 'patient-a',
            reason: 'x',
            requestKey: '0f5f65ee-5c04-4f6e-8b2a-4a6bbf6a1c11',
          ),
          throwsA(isA<InvalidResponseException>()),
          reason: 'resource ${resource['id']}',
        );
      }
    },
  );
}
