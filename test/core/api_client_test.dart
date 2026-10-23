import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:syncare_flutter/core/api_client.dart';
import 'package:syncare_flutter/core/api_exception.dart';

import '../helpers/fakes.dart';

const String _baseUrl = 'http://syncare.test';

class _Harness {
  _Harness({String? token = 'token-123'}) {
    dio = Dio();
    adapter = DioAdapter(
      dio: dio,
      matcher: const UrlRequestMatcher(matchMethod: true),
    );
    tokenSource = FakeTokenSource(token);
    client = ApiClient(baseUrl: _baseUrl, tokenSource: tokenSource, dio: dio);
  }

  late final Dio dio;
  late final DioAdapter adapter;
  late final FakeTokenSource tokenSource;
  late final ApiClient client;
}

Map<String, dynamic> _envelope(Object output) {
  return <String, dynamic>{
    'raw': <String, dynamic>{'session_id': 'session-1'},
    'outputText': output is String ? output : jsonEncode(output),
    'sessionId': 'session-1',
  };
}

final Map<String, dynamic> _healthJson = <String, dynamic>{
  'status': 'ok',
  'langflow': 'reachable',
  'reviewDbPresent': true,
  'flowCount': 5,
  'manifestComplete': true,
  'missingFlows': <String>[],
  'readOnly': false,
  'disclaimer': 'Demo sintetis.',
};

final Map<String, dynamic> _f1Json = <String, dynamic>{
  'episode': <String, dynamic>{
    'diagnosis': 'CHF NYHA III',
    'medications': <String>['furosemide 40mg'],
    'instructions': <String>['Timbang BB harian'],
    'followup_needs': <String>['Kontrol poli jantung'],
    'length_of_stay_days': 6,
    'admission_type': 'emergency',
    'comorbidity_count': 4,
    'admissions_prior_12m': 3,
  },
  'score': 4,
  'tier': 'HIGH',
  'risk_factors': <String, dynamic>{
    'length_of_stay_days': <String, dynamic>{
      'value': 6,
      'threshold': 5,
      'points': 2,
      'met': true,
    },
  },
  'rationale': 'LOS dan komorbiditas.',
  'label': 'demo-heuristic-v1',
  'missing_fields': <String>[],
  'not_clinically_validated': true,
  'synthetic_demo_only': true,
  'disclaimer': 'Demo sintetis.',
};

final Map<String, dynamic> _checkinJson = <String, dynamic>{
  'patient_id': 'demo-1',
  'baseline_score': 4,
  'baseline_tier': 'HIGH',
  'adjustments': <Map<String, dynamic>>[
    <String, dynamic>{
      'condition': 'sesak_memburuk',
      'applied': true,
      'points': 2,
    },
  ],
  'score': 6,
  'tier': 'HIGH',
  'tier_changed': true,
  'action': 'continue_monitoring',
  'next_checkin_days': 2,
  'label': 'demo-heuristic-v1',
  'disclaimer': 'Demo sintetis.',
};

void main() {
  group('auth', () {
    test('attaches the bearer token from the token source', () async {
      final harness = _Harness();
      harness.adapter.onGet(
        '/api/health',
        (server) => server.reply(200, _healthJson),
      );

      final captured = <String?>[];
      harness.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured.add(options.headers['Authorization'] as String?);
            handler.next(options);
          },
        ),
      );

      final health = await harness.client.health();
      expect(health.status, 'ok');
      expect(captured, <String>['Bearer token-123']);

      harness.tokenSource.token = 'rotated-token';
      harness.adapter.onGet(
        '/api/health',
        (server) => server.reply(200, _healthJson),
      );
      await harness.client.health();
      expect(captured.last, 'Bearer rotated-token');
    });

    test(
      'rejects with UnauthorizedException when no token is stored',
      () async {
        final harness = _Harness(token: null);

        await expectLater(
          harness.client.health(),
          throwsA(isA<UnauthorizedException>()),
        );
      },
    );
  });

  group('error mapping', () {
    test('401 becomes UnauthorizedException with the server message', () async {
      final harness = _Harness();
      harness.adapter.onGet(
        '/api/health',
        (server) => server.reply(401, <String, dynamic>{
          'error': 'unauthorized',
          'message': 'Token tidak valid.',
        }),
      );

      await expectLater(
        harness.client.health(),
        throwsA(
          isA<UnauthorizedException>().having(
            (error) => error.message,
            'message',
            'Token tidak valid.',
          ),
        ),
      );
    });

    test('503 langflow_unreachable becomes EngineWarmingException', () async {
      final harness = _Harness();
      harness.adapter.onPost(
        '/api/v1/discharge',
        (server) => server.reply(503, <String, dynamic>{
          'error': 'langflow_unreachable',
        }),
      );

      await expectLater(
        harness.client.discharge('Pasien CHF.'),
        throwsA(isA<EngineWarmingException>()),
      );
    });

    test('404 on getPlan becomes NotFoundException', () async {
      final harness = _Harness();
      harness.adapter.onGet(
        '/api/v1/plans/demo-9',
        (server) => server.reply(404, <String, dynamic>{
          'error': 'not_found',
          'message': 'Belum ada rencana.',
        }),
      );

      await expectLater(
        harness.client.getPlan('demo-9'),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  group('request shapes', () {
    test('checkin sends input_value as a JSON string', () async {
      final harness = _Harness();
      harness.adapter.onPost(
        '/api/v1/checkins',
        (server) => server.reply(200, _envelope(_checkinJson)),
      );

      Object? captured;
      harness.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured = options.data;
            handler.next(options);
          },
        ),
      );

      final result = await harness.client.checkin(
        patientId: 'demo-1',
        message: 'sesak napas naik',
      );

      expect(captured, isA<Map<String, dynamic>>());
      final body = captured! as Map<String, dynamic>;
      final inputValue = body['input_value'];
      expect(inputValue, isA<String>());
      expect(jsonDecode(inputValue! as String), <String, dynamic>{
        'patient_id': 'demo-1',
        'message': 'sesak napas naik',
      });
      expect(result.patientId, 'demo-1');
      expect(result.score, 6);
      expect(result.isTierChange, isTrue);
    });

    test('resume sends the flat backend shape with request_id', () async {
      final harness = _Harness();
      harness.adapter.onPost(
        '/api/v1/reviews/job-7/resume',
        (server) => server.reply(200, <String, dynamic>{'ok': true}),
      );

      Object? captured;
      harness.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured = options.data;
            handler.next(options);
          },
        ),
      );

      await harness.client.resumeReview(
        jobId: 'job-7',
        requestId: 'req-9',
        actionId: 'approve',
        actor: 'nurse-1',
        reviewerNote: 'Disetujui.',
      );

      final body = captured! as Map<String, dynamic>;
      expect(body['request_id'], 'req-9');
      expect(body['action_id'], 'approve');
      expect(body['actor'], 'nurse-1');
      expect(body['reviewer_note'], 'Disetujui.');
      expect(body.containsKey('decision'), isFalse);
    });

    test('discharge parses the flow envelope', () async {
      final harness = _Harness();
      harness.adapter.onPost(
        '/api/v1/discharge',
        (server) => server.reply(200, _envelope(_f1Json)),
      );

      final result = await harness.client.discharge('Pasien CHF NYHA III.');

      expect(result.tier, 'HIGH');
      expect(result.score, 4);
      expect(result.episode.diagnosis, 'CHF NYHA III');
      expect(result.riskFactors['length_of_stay_days']?.points, 2);
    });
  });
}
