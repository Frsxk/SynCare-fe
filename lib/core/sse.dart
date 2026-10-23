import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';
import 'config.dart';

/// A single Server-Sent Event frame.
class SseEvent {
  const SseEvent({this.event, required this.data, this.id});

  final String? event;
  final String data;
  final String? id;
}

/// A frame reduced to an event name and a JSON payload.
class NormalizedSseEvent {
  const NormalizedSseEvent({required this.name, required this.data});

  final String name;
  final Map<String, dynamic> data;
}

/// Normalizes both standard SSE frames and raw Langflow stream frames.
NormalizedSseEvent normalizeSseEvent(SseEvent event) {
  final explicitName = (event.event ?? '').trim();
  final decoded = _decodeJson(event.data);

  if (explicitName.isNotEmpty) {
    return NormalizedSseEvent(
      name: explicitName,
      data: _mapOrNull(decoded) ?? <String, dynamic>{'raw': event.data},
    );
  }

  final envelope = _mapOrNull(decoded);
  if (envelope != null) {
    final rawName = envelope['event'];
    final name = rawName is String && rawName.trim().isNotEmpty
        ? rawName.trim()
        : 'message';
    final payload = envelope['data'];
    final payloadMap = _mapOrNull(payload);
    if (payloadMap != null) {
      return NormalizedSseEvent(name: name, data: payloadMap);
    }
    if (payload is String) {
      return NormalizedSseEvent(
        name: name,
        data:
            _mapOrNull(_decodeJson(payload)) ??
            <String, dynamic>{'raw': payload},
      );
    }
    if (payload == null) {
      return NormalizedSseEvent(name: name, data: envelope);
    }
    return NormalizedSseEvent(
      name: name,
      data: <String, dynamic>{'value': payload},
    );
  }

  return NormalizedSseEvent(
    name: 'message',
    data: <String, dynamic>{'raw': event.data},
  );
}

/// Splits a byte stream into Server-Sent Events.
Stream<SseEvent> parseSseStream(Stream<List<int>> bytes) async* {
  final lines = bytes
      .transform(const Utf8Decoder(allowMalformed: true))
      .transform(const LineSplitter());

  String? eventName;
  String? id;
  final data = <String>[];
  var sawField = false;

  await for (final line in lines) {
    if (line.isEmpty) {
      if (sawField) {
        yield SseEvent(event: eventName, data: data.join('\n'), id: id);
      }
      eventName = null;
      id = null;
      data.clear();
      sawField = false;
      continue;
    }

    if (line.startsWith(':')) {
      continue;
    }

    final separator = line.indexOf(':');
    final String field;
    String value;
    if (separator == -1) {
      field = line;
      value = '';
    } else {
      field = line.substring(0, separator);
      value = line.substring(separator + 1);
      if (value.startsWith(' ')) {
        value = value.substring(1);
      }
    }

    switch (field) {
      case 'event':
        eventName = value;
        sawField = true;
      case 'data':
        data.add(value);
        sawField = true;
      case 'id':
        id = value;
        sawField = true;
    }
  }

  if (sawField) {
    yield SseEvent(event: eventName, data: data.join('\n'), id: id);
  }
}

/// Source of review SSE frames.
abstract class ReviewEventSource {
  Stream<SseEvent> events(String jobId);
}

/// SSE source backed by `package:http`, so the bearer token travels in a
/// header rather than a query string.
class HttpReviewEventSource implements ReviewEventSource {
  HttpReviewEventSource({
    required String baseUrl,
    required this._tokenSource,
    this._client,
  }) : _baseUrl = _normalizeBaseUrl(baseUrl);

  final String _baseUrl;
  final TokenSource _tokenSource;
  final http.Client? _client;

  @override
  Stream<SseEvent> events(String jobId) async* {
    final client = _client ?? http.Client();
    try {
      final token = await _readToken();
      final uri = Uri.parse(
        '$_baseUrl/api/v1/reviews/${Uri.encodeComponent(jobId)}/events',
      );
      final request = http.Request('GET', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..headers['Accept'] = 'text/event-stream'
        ..headers['Cache-Control'] = 'no-cache';

      http.StreamedResponse response;
      try {
        response = await client
            .send(request)
            .timeout(const Duration(seconds: 15));
      } on Exception {
        throw const NetworkException();
      }

      if (response.statusCode != 200) {
        var body = '';
        try {
          body = await response.stream.bytesToString();
        } on Exception {
          body = '';
        }
        throw apiExceptionForStatus(response.statusCode, body);
      }

      yield* parseSseStream(response.stream);
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  Future<String> _readToken() async {
    try {
      final token = await _tokenSource.read();
      if (token == null || token.isEmpty) {
        throw const UnauthorizedException();
      }
      return token;
    } on ApiException {
      rethrow;
    } on Exception {
      throw const UnauthorizedException();
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

Object? _decodeJson(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  try {
    return jsonDecode(trimmed);
  } on FormatException {
    return null;
  }
}

Map<String, dynamic>? _mapOrNull(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return null;
}
