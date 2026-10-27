import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:syncare_flutter/core/api_client.dart';
import 'package:syncare_flutter/core/api_exception.dart';
import 'package:syncare_flutter/models/ask_answer.dart';
import '../helpers/fakes.dart';

void main() {
  test(
    'Q1 uses authorized patient URL with exact query body and parses a typed refusal',
    () async {
      final dio = Dio(),
          adapter = DioAdapter(
            dio: dio,
            matcher: const UrlRequestMatcher(matchMethod: true),
          ),
          client = ApiClient(
            baseUrl: 'http://syncare.test',
            tokenSource: FakeTokenSource('private-fixture-token'),
            dio: dio,
          );
      adapter.onPost(
        '/api/v1/patients/patient-a/questions',
        (server) => server.reply(200, {
          'data': {'kind': 'refusal', 'text': 'Penolakan asli dari fixture.'},
          'requestId': 'fixture',
        }),
        data: {'query': 'pertanyaan'},
      );
      final answer = await client.ask(
        patientId: 'patient-a',
        query: 'pertanyaan',
      );
      expect(answer, isA<QuestionRefusal>());
      expect((answer as QuestionRefusal).text, 'Penolakan asli dari fixture.');
      dio.close();
    },
  );
  test(
    'Q1 never stringifies legacy raw JSON into a successful medical answer',
    () async {
      final dio = Dio(),
          adapter = DioAdapter(dio: dio),
          client = ApiClient(
            baseUrl: 'http://syncare.test',
            tokenSource: FakeTokenSource('fixture-token'),
            dio: dio,
          );
      adapter.onPost(
        '/api/v1/patients/patient-a/questions',
        (server) => server.reply(200, {
          'outputText': '{"action":"escalate_immediately","reason":"private"}',
        }),
        data: {'query': 'pertanyaan'},
      );
      await expectLater(
        client.ask(patientId: 'patient-a', query: 'pertanyaan'),
        throwsA(isA<InvalidResponseException>()),
      );
      dio.close();
    },
  );
}
