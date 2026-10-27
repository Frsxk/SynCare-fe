import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/session.dart';
import 'config.dart';

final tokenSourceProvider = Provider<TokenSource>((ref) => SecureTokenSource());
final sessionApiProvider = Provider<SessionApi>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: validateSessionBaseUrl(AppConfig.apiBase),
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      contentType: Headers.jsonContentType,
      followRedirects: false,
    ),
  );
  ref.onDispose(() => dio.close(force: true));
  return DioSessionApi(dio);
});

abstract interface class SessionApi {
  Future<SessionGrant> login(String identifier, String password);
  Future<SessionSnapshot> restore(String token);
  Future<void> revoke(String token);
}

class DioSessionApi implements SessionApi {
  DioSessionApi(this._dio);
  final Dio _dio;

  Future<Object?> _request(
    String method,
    String path, {
    String? token,
    Object? body,
  }) async {
    try {
      final response = await _dio.request<Object?>(
        path,
        data: body,
        options: Options(
          method: method,
          headers: {
            if (token != null) 'Authorization': 'Bearer $token',
            'Cache-Control': 'no-store',
          },
        ),
      );
      if (response.statusCode == 204) return null;
      if (response.data case {'data': final Object data}) return data;
      throw const SessionException(SessionFailure.invalidResponse);
    } on DioException catch (error) {
      throw SessionException(switch (error.response?.statusCode) {
        401 => SessionFailure.invalidCredentials,
        422 => SessionFailure.invalidInput,
        429 => SessionFailure.rateLimited,
        _ => SessionFailure.unavailable,
      });
    }
  }

  @override
  Future<SessionGrant> login(String identifier, String password) async =>
      SessionGrant.fromJson(
        await _request(
          'POST',
          '/api/v1/auth/login',
          body: {'identifier': identifier, 'password': password},
        ),
      );

  @override
  Future<SessionSnapshot> restore(String token) async =>
      SessionSnapshot.fromJson(
        await _request('GET', '/api/v1/auth/session', token: token),
      );

  @override
  Future<void> revoke(String token) async {
    await _request('DELETE', '/api/v1/auth/session', token: token);
  }
}
