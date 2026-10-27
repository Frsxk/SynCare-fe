enum SessionFailure {
  invalidCredentials,
  expired,
  unavailable,
  invalidResponse,
  rateLimited,
  storage,
  invalidInput;

  String get message => switch (this) {
    invalidCredentials => 'Akun atau kata sandi tidak sesuai.',
    expired => 'Sesi telah berakhir. Silakan masuk kembali.',
    unavailable => 'Belum dapat terhubung. Periksa koneksi lalu coba lagi.',
    invalidResponse => 'Respons layanan belum dapat digunakan. Coba lagi.',
    rateLimited => 'Terlalu banyak percobaan masuk. Coba kembali nanti.',
    storage => 'Sesi belum dapat disimpan dengan aman. Coba lagi.',
    invalidInput => 'Isi identitas akun dan kata sandi terlebih dahulu.',
  };
}

class SessionException implements Exception {
  const SessionException(this.failure);
  final SessionFailure failure;
}

class SessionPrincipal {
  const SessionPrincipal({
    required this.id,
    required this.role,
    required this.capabilities,
    this.patientId,
  });

  final String id;
  final String role;
  final List<String> capabilities;
  final String? patientId;

  factory SessionPrincipal.fromJson(Object? value) {
    if (value case {
      'id': final String id,
      'role': final String role,
      'capabilities': final List<Object?> capabilities,
    }) {
      final patientId = (value as Map)['patientId'];
      if (id.isNotEmpty &&
          (role == 'nurse' || role == 'patient') &&
          capabilities.every((item) => item is String) &&
          (role != 'patient' || patientId is String && patientId.isNotEmpty)) {
        return SessionPrincipal(
          id: id,
          role: role,
          capabilities: List<String>.unmodifiable(capabilities.cast<String>()),
          patientId: patientId is String ? patientId : null,
        );
      }
    }
    throw const SessionException(SessionFailure.invalidResponse);
  }
}

class SessionSnapshot {
  const SessionSnapshot({required this.principal, required this.expiresAt});
  final SessionPrincipal principal;
  final DateTime expiresAt;

  factory SessionSnapshot.fromJson(Object? value) {
    if (value case {
      'principal': final Object principal,
      'expiresAt': final String expiry,
    }) {
      final expiresAt = DateTime.tryParse(expiry);
      if (expiresAt != null) {
        return SessionSnapshot(
          principal: SessionPrincipal.fromJson(principal),
          expiresAt: expiresAt.toUtc(),
        );
      }
    }
    throw const SessionException(SessionFailure.invalidResponse);
  }
}

class SessionGrant {
  const SessionGrant({required this.token, required this.session});
  final String token;
  final SessionSnapshot session;

  factory SessionGrant.fromJson(Object? value) {
    if (value case {'sessionToken': final String token}) {
      if (RegExp(r'^sc_[A-Za-z0-9_-]{43}$').hasMatch(token)) {
        return SessionGrant(
          token: token,
          session: SessionSnapshot.fromJson(value),
        );
      }
    }
    throw const SessionException(SessionFailure.invalidResponse);
  }
}

sealed class SessionState {
  const SessionState(this.generation);
  final int generation;
}

class SessionChecking extends SessionState {
  const SessionChecking(super.generation);
}

class SessionSignedOut extends SessionState {
  const SessionSignedOut(
    super.generation, {
    this.failure,
    this.revokeUnconfirmed = false,
  });
  final SessionFailure? failure;
  final bool revokeUnconfirmed;
}

class SessionUnverified extends SessionState {
  const SessionUnverified(super.generation, this.failure);
  final SessionFailure failure;
}

class SessionAuthenticated extends SessionState {
  const SessionAuthenticated(super.generation, this.session);
  final SessionSnapshot session;
}
