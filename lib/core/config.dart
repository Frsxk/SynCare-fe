import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Compile-time configuration for the SynCare client.
class AppConfig {
  const AppConfig._();

  static const String apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://10.0.2.2:8080',
  );
  static const String compiledToken = String.fromEnvironment('API_TOKEN');
  static const String defaultPatientId = String.fromEnvironment(
    'PATIENT_ID',
    defaultValue: 'demo-1',
  );
  static const String defaultReviewer = String.fromEnvironment(
    'REVIEWER',
    defaultValue: 'nurse-1',
  );
}

/// Reads and persists the API bearer token.
abstract class TokenSource {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

/// Token source backed by [FlutterSecureStorage], with an in-memory cache.
///
/// A non-empty [AppConfig.compiledToken] always wins over stored values.
class SecureTokenSource implements TokenSource {
  SecureTokenSource({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String _storageKey = 'syncare_api_token';

  final FlutterSecureStorage _storage;
  String? _cached;
  bool _loaded = false;

  @override
  Future<String?> read() async {
    if (AppConfig.compiledToken.isNotEmpty) {
      return AppConfig.compiledToken;
    }
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
    _cached = token;
    _loaded = true;
    await _storage.write(key: _storageKey, value: token);
  }

  @override
  Future<void> clear() async {
    _cached = null;
    _loaded = true;
    await _storage.delete(key: _storageKey);
  }
}
