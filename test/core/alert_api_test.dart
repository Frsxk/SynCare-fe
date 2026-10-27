import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:syncare_flutter/core/api_client.dart';
import 'package:syncare_flutter/core/api_exception.dart';
import '../helpers/fakes.dart';
import '../helpers/escalation_fixture.dart';

void main() {
  test(
    'Dio E1/E3 own bounded pages/detail uses server evidence and rejects foreign or private response',
    () async {
      final dio = Dio(),
          api = ApiClient(
            baseUrl: 'http://syncare.test',
            tokenSource: FakeTokenSource('synthetic-session'),
            dio: dio,
          ),
          wire = DioAdapter(dio: dio);
      addTearDown(() => dio.close(force: true));
      wire.onGet(
        '/api/v1/patients/patient-a/alerts',
        (s) => s.reply(200, {
          'data': [escalationJson()],
          'nextCursor': null,
          'requestId': 'test',
        }),
        queryParameters: {'limit': 20},
      );
      expect(
        (await api.listEscalations('patient-a')).alerts.single.id,
        'alert-a',
      );
      wire.onGet(
        '/api/v1/alerts/alert-a',
        (s) => s.reply(200, {
          'data': escalationJson(status: 'RESOLVED'),
          'requestId': 'test',
        }),
        queryParameters: {'limit': 20},
      );
      expect((await api.getEscalation('alert-a')).timeline.length, 4);
      wire.onGet(
        '/api/v1/patients/patient-b/alerts',
        (s) => s.reply(200, {
          'data': [escalationJson()],
          'nextCursor': null,
          'requestId': 'test',
        }),
        queryParameters: {'limit': 20},
      );
      await expectLater(
        api.listEscalations('patient-b'),
        throwsA(isA<InvalidResponseException>()),
      );
    },
  );
}
