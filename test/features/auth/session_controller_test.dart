import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncare_flutter/core/config.dart';
import 'package:syncare_flutter/core/session_api.dart';
import 'package:syncare_flutter/features/auth/session_controller.dart';
import 'package:syncare_flutter/models/session.dart';

import '../../helpers/fakes.dart';

class FakeSessionApi implements SessionApi {
  Future<SessionGrant> Function(String, String)? onLogin;
  Future<SessionSnapshot> Function(String)? onRestore;
  Future<void> Function(String)? onRevoke;
  final revoked = <String>[];
  @override
  Future<SessionGrant> login(String identifier, String password) =>
      onLogin!(identifier, password);
  @override
  Future<SessionSnapshot> restore(String token) => onRestore!(token);
  @override
  Future<void> revoke(String token) async {
    revoked.add(token);
    await onRevoke?.call(token);
  }
}

SessionGrant grant(String id) => SessionGrant(
  token: 'synthetic-session-$id',
  session: SessionSnapshot(
    principal: SessionPrincipal(
      id: id,
      role: 'patient',
      patientId: 'record-$id',
      capabilities: const [],
    ),
    expiresAt: DateTime.now().toUtc().add(const Duration(days: 1)),
  ),
);

Future<ProviderContainer> container(
  FakeSessionApi api,
  TokenSource storage,
) async {
  final result = ProviderContainer(
    overrides: [
      sessionApiProvider.overrideWithValue(api),
      tokenSourceProvider.overrideWithValue(storage),
    ],
  );
  addTearDown(result.dispose);
  result.read(sessionControllerProvider);
  await Future<void>.delayed(Duration.zero);
  return result;
}

void main() {
  test(
    'restore validates the server and uses its patient identity; expiry clears the secure credential',
    () async {
      final storage = FakeTokenSource('saved-token');
      final api = FakeSessionApi()..onRestore = (_) async => grant('a').session;
      final scope = await container(api, storage);
      final state =
          scope.read(sessionControllerProvider) as SessionAuthenticated;
      expect(state.session.principal.patientId, 'record-a');
      api.onRestore = (_) async =>
          throw const SessionException(SessionFailure.invalidCredentials);
      await scope.read(sessionControllerProvider.notifier).restore();
      expect(scope.read(sessionControllerProvider), isA<SessionSignedOut>());
      expect(storage.token, isNull);
    },
  );

  test(
    'offline restore remains unverified, keeps only the private credential and supports retry',
    () async {
      final storage = FakeTokenSource('saved-token');
      final api = FakeSessionApi()
        ..onRestore = (_) async =>
            throw const SessionException(SessionFailure.unavailable);
      final scope = await container(api, storage);
      expect(scope.read(sessionControllerProvider), isA<SessionUnverified>());
      final controller = scope.read(sessionControllerProvider.notifier);
      expect(
        controller.tokenFor(scope.read(sessionControllerProvider).generation),
        isNull,
      );
      expect(storage.token, 'saved-token');
      api.onRestore = (_) async => grant('a').session;
      await controller.restore();
      expect(
        scope.read(sessionControllerProvider),
        isA<SessionAuthenticated>(),
      );
    },
  );

  test(
    'late_response_ignored_after_account_switch: delayed login A cannot replace B or persist A credential',
    () async {
      final delayed = Completer<SessionGrant>();
      final storage = FakeTokenSource();
      final api = FakeSessionApi()
        ..onLogin = (id, _) =>
            id == 'a' ? delayed.future : Future.value(grant('b'));
      final scope = await container(api, storage);
      final controller = scope.read(sessionControllerProvider.notifier);
      final first = controller.login('a', 'synthetic-password');
      await Future<void>.delayed(Duration.zero);
      await controller.login('b', 'synthetic-password');
      final generation = scope.read(sessionControllerProvider).generation;
      delayed.complete(grant('a'));
      await first;
      expect(
        (scope.read(sessionControllerProvider) as SessionAuthenticated)
            .session
            .principal
            .id,
        'b',
      );
      expect(storage.token, 'synthetic-session-b');
      expect(controller.tokenFor(generation - 1), isNull);
      expect(api.revoked, contains('synthetic-session-a'));
    },
  );

  test(
    'an old generation token source cannot send pending input under the next account',
    () async {
      final storage = FakeTokenSource();
      final api = FakeSessionApi()..onLogin = (id, _) async => grant(id);
      final scope = await container(api, storage);
      final controller = scope.read(sessionControllerProvider.notifier);
      await controller.login('a', 'synthetic-password');
      final old = GenerationTokenSource(
        controller,
        scope.read(sessionControllerProvider).generation,
      );
      expect(await old.read(), 'synthetic-session-a');
      await controller.login('b', 'synthetic-password');
      expect(await old.read(), isNull);
      expect(api.revoked, contains('synthetic-session-a'));
    },
  );

  test(
    'offline logout closes local access immediately and reports unconfirmed remote revocation',
    () async {
      final pending = Completer<void>();
      final storage = FakeTokenSource();
      final api = FakeSessionApi()..onLogin = (id, _) async => grant(id);
      final scope = await container(api, storage);
      final controller = scope.read(sessionControllerProvider.notifier);
      await controller.login('a', 'synthetic-password');
      final generation = scope.read(sessionControllerProvider).generation;
      api.onRevoke = (_) => pending.future;
      final logout = controller.logout();
      expect(scope.read(sessionControllerProvider), isA<SessionSignedOut>());
      expect(controller.tokenFor(generation), isNull);
      await Future<void>.delayed(Duration.zero);
      expect(storage.token, isNull);
      pending.completeError(const SessionException(SessionFailure.unavailable));
      await logout;
      expect(
        (scope.read(sessionControllerProvider) as SessionSignedOut)
            .revokeUnconfirmed,
        isTrue,
      );
    },
  );

  test(
    'invalid login never creates local authenticated state and a successful logout confirms revocation',
    () async {
      final storage = FakeTokenSource();
      final api = FakeSessionApi()
        ..onLogin = (_, _) async =>
            throw const SessionException(SessionFailure.invalidCredentials);
      final scope = await container(api, storage);
      final controller = scope.read(sessionControllerProvider.notifier);
      await controller.login('a', 'wrong');
      expect(
        (scope.read(sessionControllerProvider) as SessionSignedOut).failure,
        SessionFailure.invalidCredentials,
      );
      expect(storage.token, isNull);
      api.onLogin = (id, _) async => grant(id);
      await controller.login('a', 'synthetic-password');
      await controller.logout();
      expect(
        (scope.read(sessionControllerProvider) as SessionSignedOut)
            .revokeUnconfirmed,
        isFalse,
      );
      expect(storage.token, isNull);
    },
  );

  test(
    'session transport permits only HTTPS or the documented local development hosts',
    () {
      for (final origin in [
        'http://10.0.2.2:8080',
        'http://127.0.0.1:8080',
        'https://synthetic.invalid',
      ]) {
        expect(validateSessionBaseUrl(origin), origin);
      }
      for (final origin in [
        'http://192.168.1.1',
        'http://localhost.attacker.invalid',
        'https://user:pass@synthetic.invalid',
        'https://synthetic.invalid/api',
      ]) {
        expect(() => validateSessionBaseUrl(origin), throwsArgumentError);
      }
    },
  );
}
