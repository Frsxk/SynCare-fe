import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:syncare_flutter/core/api_exception.dart';
import 'package:syncare_flutter/core/sse.dart';

import '../helpers/fakes.dart';

const String _baseUrl = 'http://syncare.test';

Stream<List<int>> _chunks(List<String> pieces) async* {
  for (final piece in pieces) {
    yield utf8.encode(piece);
  }
}

Future<List<SseEvent>> _parse(List<String> pieces) {
  return parseSseStream(_chunks(pieces)).toList();
}

void main() {
  group('parseSseStream', () {
    test('parses standard event/data frames', () async {
      final events = await _parse(<String>[
        'event: human_input_required\n',
        'data: {"request_id":"req-1","timeout_seconds":300}\n\n',
        'event: output\n',
        'data: {"type":"end"}\n\n',
      ]);

      expect(events, hasLength(2));
      expect(events[0].event, 'human_input_required');
      expect(events[0].data, '{"request_id":"req-1","timeout_seconds":300}');
      expect(events[1].event, 'output');
      expect(events[1].data, '{"type":"end"}');
    });

    test('parses raw Langflow frames with no event line', () async {
      final events = await _parse(<String>[
        'data: {"event":"human_input_required","data":{"request_id":"req-1"}}\n\n',
      ]);

      expect(events, hasLength(1));
      expect(events.single.event, isNull);
      expect(
        events.single.data,
        '{"event":"human_input_required","data":{"request_id":"req-1"}}',
      );
    });

    test('accepts CRLF separators and ignores comments', () async {
      final events = await _parse(<String>[
        ': keep-alive\r\n',
        'event: output\r\n',
        'data: {"a": 1}\r\n',
        '\r\n',
      ]);

      expect(events, hasLength(1));
      expect(events.single.event, 'output');
      expect(events.single.data, '{"a": 1}');
    });

    test('joins multi-line data with newlines', () async {
      final events = await _parse(<String>[
        'event: output\n',
        'data: {"a":\n',
        'data: 1}\n',
        '\n',
      ]);

      expect(events, hasLength(1));
      expect(events.single.data, '{"a":\n1}');
      expect(normalizeSseEvent(events.single).data['a'], 1);
    });

    test('handles chunk boundaries, including split CRLF', () async {
      final events = await _parse(<String>[
        'event: outp',
        'ut\rdata: {"x"',
        ': "y"}\r',
        '\n\r\n',
      ]);

      expect(events, hasLength(1));
      expect(events.single.event, 'output');
      expect(events.single.data, '{"x": "y"}');
    });

    test('flushes a final frame without a trailing blank line', () async {
      final events = await _parse(<String>['data: {"event":"end","data":{}}']);

      expect(events, hasLength(1));
      expect(events.single.data, '{"event":"end","data":{}}');
    });
  });

  group('normalizeSseEvent', () {
    test('uses an explicit event name and decodes its data', () {
      const event = SseEvent(
        event: 'human_input_required',
        data: '{"request_id":"req-1"}',
      );

      final normalized = normalizeSseEvent(event);
      expect(normalized.name, 'human_input_required');
      expect(normalized.data['request_id'], 'req-1');
    });

    test('unwraps raw Langflow envelopes', () {
      const event = SseEvent(
        data: '{"event":"human_input_required","data":{"request_id":"req-1"}}',
      );

      final normalized = normalizeSseEvent(event);
      expect(normalized.name, 'human_input_required');
      expect(normalized.data['request_id'], 'req-1');
    });

    test('falls back to message and raw payload for non-JSON data', () {
      const event = SseEvent(data: 'plain text');

      final normalized = normalizeSseEvent(event);
      expect(normalized.name, 'message');
      expect(normalized.data['raw'], 'plain text');
    });

    test('keeps the explicit name when its data is not JSON', () {
      const event = SseEvent(event: 'error', data: 'boom');

      final normalized = normalizeSseEvent(event);
      expect(normalized.name, 'error');
      expect(normalized.data['raw'], 'boom');
    });
  });

  group('HttpReviewEventSource', () {
    test('sends bearer auth and streams parsed events', () async {
      late http.BaseRequest captured;
      final client = MockClient.streaming((request, bodyStream) async {
        captured = request;
        return http.StreamedResponse(
          Stream<List<int>>.value(
            utf8.encode('data: {"event":"end","data":{}}\n\n'),
          ),
          200,
        );
      });
      final source = HttpReviewEventSource(
        baseUrl: _baseUrl,
        tokenSource: FakeTokenSource('token-123'),
        client: client,
      );

      final events = await source.events('job-1').toList();

      expect(events, hasLength(1));
      expect(captured.url.path, '/api/v1/reviews/job-1/events');
      expect(captured.headers['Authorization'], 'Bearer token-123');
      expect(captured.headers['Accept'], 'text/event-stream');
      expect(captured.url.queryParameters.containsKey('token'), isFalse);
    });

    test('maps non-200 responses to API exceptions', () async {
      final client = MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(
          Stream<List<int>>.value(
            utf8.encode('{"error":"events_unavailable","message":"mati"}'),
          ),
          502,
        );
      });
      final source = HttpReviewEventSource(
        baseUrl: _baseUrl,
        tokenSource: FakeTokenSource('token-123'),
        client: client,
      );

      await expectLater(
        source.events('job-1').toList(),
        throwsA(
          isA<StreamUnavailableException>().having(
            (error) => error.message,
            'message',
            'mati',
          ),
        ),
      );
    });

    test('rejects without a token before opening a connection', () async {
      var called = false;
      final client = MockClient.streaming((request, bodyStream) async {
        called = true;
        return http.StreamedResponse(const Stream<List<int>>.empty(), 200);
      });
      final source = HttpReviewEventSource(
        baseUrl: _baseUrl,
        tokenSource: FakeTokenSource(null),
        client: client,
      );

      await expectLater(
        source.events('job-1').toList(),
        throwsA(isA<UnauthorizedException>()),
      );
      expect(called, isFalse);
    });
  });
}
