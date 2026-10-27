import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncare_flutter/core/config.dart';

class RecordingStorage extends FlutterSecureStorage {
  RecordingStorage(this.values);
  final Map<String, String> values;
  final calls = <String>[];
  bool failDelete = false;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    calls.add('read:$key');
    return values[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    calls.add('write:$key');
    if (value != null) values[key] = value;
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    calls.add('delete:$key');
    if (failDelete) throw StateError('synthetic storage failure');
    values.remove(key);
  }
}

void main() {
  test(
    'legacy grant is removed, never adopted; only current tab grant restores',
    () async {
      final legacy = RecordingStorage({
        'syncare_session_token': 'old-account',
        'other': 'retained',
      });
      final current = RecordingStorage({});
      final source = SecureTokenSource(storage: current, legacyStorage: legacy);
      expect(await source.read(), isNull);
      expect(legacy.values, {'other': 'retained'});
      await source.write('current-account');
      expect(await source.read(), 'current-account');
      expect(legacy.calls.where((call) => call.startsWith('read:')), isEmpty);
      expect(legacy.calls.length, 1);
      await source.clear();
      expect(await source.read(), isNull);
      expect(current.values, isEmpty);
    },
  );

  test(
    'failed legacy removal fails closed before restore or a new write',
    () async {
      final legacy = RecordingStorage({'syncare_session_token': 'old-account'})
        ..failDelete = true;
      final current = RecordingStorage({
        'syncare_session_token': 'current-account',
      });
      final source = SecureTokenSource(storage: current, legacyStorage: legacy);
      await expectLater(source.read(), throwsStateError);
      await expectLater(source.write('replacement'), throwsStateError);
      expect(current.calls, isEmpty);
      expect(legacy.values['syncare_session_token'], 'old-account');
    },
  );
}
