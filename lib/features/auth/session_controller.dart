import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/session_api.dart';
import '../../models/session.dart';

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

class SessionController extends Notifier<SessionState> {
  int _generation = 0;
  bool _disposed = false;
  String? _token;
  Timer? _expiry;
  Future<void> _storage = Future.value();

  @override
  SessionState build() {
    ref.onDispose(() {
      _disposed = true;
      _generation++;
      _expiry?.cancel();
      _token = null;
    });
    Future.microtask(restore);
    return const SessionChecking(0);
  }

  String? tokenFor(int generation) =>
      !_disposed && generation == _generation && state is SessionAuthenticated
      ? _token
      : null;
  bool _current(int generation) => !_disposed && generation == _generation;

  Future<void> _persist(Future<void> Function() operation) {
    final next = _storage.then((_) => operation());
    _storage = next.catchError((Object _) {});
    return next;
  }

  void _authenticated(int generation, SessionSnapshot session, String token) {
    if (!_current(generation)) return;
    if (!session.expiresAt.isAfter(DateTime.now().toUtc())) {
      unawaited(expire());
      return;
    }
    _token = token;
    state = SessionAuthenticated(generation, session);
    _expiry?.cancel();
    _expiry = Timer(
      session.expiresAt.difference(DateTime.now().toUtc()),
      () => unawaited(expire()),
    );
  }

  Future<void> restore() async {
    if (_disposed) return;
    final generation = ++_generation;
    _token = null;
    _expiry?.cancel();
    state = SessionChecking(generation);
    final storage = ref.read(tokenSourceProvider);
    final api = ref.read(sessionApiProvider);
    try {
      await _storage;
      final token = await storage.read();
      if (!_current(generation)) return;
      if (token == null || token.isEmpty) {
        state = SessionSignedOut(generation);
        return;
      }
      final session = await api.restore(token);
      if (_current(generation)) _authenticated(generation, session, token);
    } on SessionException catch (error) {
      if (!_current(generation)) return;
      if (error.failure == SessionFailure.invalidCredentials) {
        try {
          await _persist(storage.clear);
          if (_current(generation)) {
            state = SessionSignedOut(
              generation,
              failure: SessionFailure.expired,
            );
          }
        } on Exception {
          if (_current(generation)) {
            state = SessionUnverified(generation, SessionFailure.storage);
          }
        }
      } else {
        state = SessionUnverified(generation, error.failure);
      }
    } on Exception {
      if (_current(generation)) {
        state = SessionUnverified(generation, SessionFailure.storage);
      }
    }
  }

  Future<void> login(String identifier, String password) async {
    if (_disposed) return;
    final generation = ++_generation;
    final previous = _token;
    _token = null;
    _expiry?.cancel();
    state = SessionChecking(generation);
    final storage = ref.read(tokenSourceProvider);
    final api = ref.read(sessionApiProvider);
    String? issuedToken;
    try {
      await _persist(storage.clear);
      if (!_current(generation)) return;
      if (previous != null) {
        try {
          await api.revoke(previous);
        } on Exception {
          /* Absolute expiry bounds an unconfirmed remote revocation. */
        }
      }
      if (!_current(generation)) return;
      if (identifier.trim().isEmpty || password.isEmpty) {
        throw const SessionException(SessionFailure.invalidInput);
      }
      final grant = await api.login(identifier.trim(), password);
      issuedToken = grant.token;
      if (!_current(generation)) {
        await _discardGrant(api, grant.token);
        return;
      }
      await _persist(() => storage.write(grant.token));
      if (!_current(generation)) {
        await _discardGrant(api, grant.token);
        return;
      }
      _authenticated(generation, grant.session, grant.token);
    } on SessionException catch (error) {
      if (_current(generation)) {
        state = SessionSignedOut(generation, failure: error.failure);
      }
    } on Exception {
      if (_current(generation)) {
        if (issuedToken != null) await _discardGrant(api, issuedToken);
        if (_current(generation)) {
          state = SessionSignedOut(generation, failure: SessionFailure.storage);
        }
      }
    }
  }

  Future<void> _discardGrant(SessionApi api, String token) async {
    try {
      await api.revoke(token);
    } on Exception {
      /* Never expose a discarded login grant to another generation. */
    }
  }

  Future<void> logout() async {
    if (_disposed) return;
    final generation = ++_generation;
    final token = _token;
    final storage = ref.read(tokenSourceProvider);
    final api = ref.read(sessionApiProvider);
    _token = null;
    _expiry?.cancel();
    state = SessionSignedOut(generation);
    var unconfirmed = false;
    SessionFailure? failure;
    try {
      await _persist(storage.clear);
    } on Exception {
      if (_current(generation)) {
        state = SessionSignedOut(
          generation,
          failure: SessionFailure.storage,
          revokeUnconfirmed: true,
        );
      }
      unconfirmed = true;
      failure = SessionFailure.storage;
    }
    if (token != null) {
      try {
        await api.revoke(token);
      } on Exception {
        unconfirmed = true;
      }
    }
    if (_current(generation)) {
      state = SessionSignedOut(
        generation,
        failure: failure,
        revokeUnconfirmed: unconfirmed,
      );
    }
  }

  Future<void> expire() async {
    if (_disposed) return;
    final generation = ++_generation;
    final storage = ref.read(tokenSourceProvider);
    _token = null;
    _expiry?.cancel();
    state = SessionSignedOut(generation, failure: SessionFailure.expired);
    try {
      await _persist(storage.clear);
    } on Exception {
      if (_current(generation)) {
        state = SessionSignedOut(generation, failure: SessionFailure.storage);
      }
    }
  }
}

class GenerationTokenSource implements TokenSource {
  GenerationTokenSource(this._controller, this._generation);
  final SessionController _controller;
  final int _generation;
  @override
  Future<String?> read() async => _controller.tokenFor(_generation);
  @override
  Future<void> write(String token) async =>
      throw StateError('Session controller owns credentials.');
  @override
  Future<void> clear() async =>
      throw StateError('Session controller owns credentials.');
}
