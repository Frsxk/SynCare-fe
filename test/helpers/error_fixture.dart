import 'dart:convert';

/// Actual backend domain-error envelope:
/// `{"error":{"code","message","requestId","retryable"}}`.
String nestedErrorBody(
  String code, {
  String message = 'Pesan publik sintetis.',
  String requestId = 'req-test',
  bool retryable = false,
}) => jsonEncode(<String, Object?>{
  'error': <String, Object?>{
    'code': code,
    'message': message,
    'requestId': requestId,
    'retryable': retryable,
  },
});

/// Deliberate legacy flat envelope still served by older routes.
String legacyErrorBody(String code, {String? message}) =>
    jsonEncode(<String, Object?>{'error': code, 'message': ?message});
