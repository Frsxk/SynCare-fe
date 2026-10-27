import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

/// Compile-time configuration for the SynCare client.
class AppConfig {
  const AppConfig._();

  static const String apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://10.0.2.2:8080',
  );
  static const String defaultPatientId = String.fromEnvironment(
    'PATIENT_ID',
    defaultValue: 'demo-1',
  );
  static const String defaultReviewer = String.fromEnvironment(
    'REVIEWER',
    defaultValue: 'nurse-1',
  );
}

/// Reads and persists the current account session credential.
abstract class TokenSource {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

/// Token source backed by [FlutterSecureStorage], with an in-memory cache.
class SecureTokenSource implements TokenSource {
  SecureTokenSource({
    FlutterSecureStorage? storage,
    FlutterSecureStorage? legacyStorage,
  }) : _storage =
           storage ??
           const FlutterSecureStorage(
             webOptions: WebOptions(useSessionStorage: true),
           ),
       _legacyStorage =
           legacyStorage ??
           (kIsWeb && storage == null ? const FlutterSecureStorage() : null);

  static const String _storageKey = 'syncare_session_token';

  final FlutterSecureStorage _storage;
  final FlutterSecureStorage? _legacyStorage;
  Future<void>? _migration;
  String? _cached;
  bool _loaded = false;

  Future<void> _removeLegacyGrant() =>
      _migration ??= _legacyStorage?.delete(key: _storageKey) ?? Future.value();

  @override
  Future<String?> read() async {
    await _removeLegacyGrant();
    if (_loaded) {
      return _cached;
    }
    final stored = await _storage.read(key: _storageKey);
    _cached = (stored == null || stored.isEmpty) ? null : stored;
    _loaded = true;
    return _cached;
  }

  @override
  Future<void> write(String token) async {
    await _removeLegacyGrant();
    await _storage.write(key: _storageKey, value: token);
    _cached = token;
    _loaded = true;
  }

  @override
  Future<void> clear() async {
    _cached = null;
    _loaded = true;
    await _removeLegacyGrant();
    await _storage.delete(key: _storageKey);
  }
}

String validateSessionBaseUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.path.isNotEmpty && uri.path != '/' ||
      uri.scheme != 'https' &&
          !(uri.scheme == 'http' &&
              const [
                'localhost',
                '127.0.0.1',
                '::1',
                '10.0.2.2',
              ].contains(uri.host))) {
    throw ArgumentError(
      'HTTPS or the documented local development host is required.',
    );
  }
  return uri.origin;
}
