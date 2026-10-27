import 'package:flutter/material.dart';

import '../core/api_exception.dart';

/// Full-screen error state that maps typed API failures to Indonesian copy.
/// Raw exception text (and stack traces) are never rendered.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.error,
    this.onRetry,
    this.onReauth,
    this.tokenReauth = false,
  });

  final Object error;
  final VoidCallback? onRetry;
  final VoidCallback? onReauth;

  /// Retained legacy nurse and patient widgets still offer the manual token
  /// dialog. Routed patient screens use the default sign-in-again affordance.
  final bool tokenReauth;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final _ErrorCopy copy = _copyFor(error);
    final bool isAuth = copy.action == _ErrorAction.reauth;

    final VoidCallback? actionCallback = switch (copy.action) {
      _ErrorAction.retry => onRetry,
      _ErrorAction.reauth => onReauth,
      _ErrorAction.none => null,
    };

    return Semantics(
      container: true,
      liveRegion: true,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isAuth
                        ? scheme.errorContainer
                        : scheme.surfaceContainerHigh,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    copy.icon,
                    size: 28,
                    color: isAuth
                        ? scheme.onErrorContainer
                        : scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  copy.title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  copy.message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                if (actionCallback != null) ...<Widget>[
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: actionCallback,
                    icon: Icon(
                      isAuth
                          ? tokenReauth
                                ? Icons.key_outlined
                                : Icons.login
                          : Icons.refresh,
                    ),
                    label: Text(copy.actionLabel),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  _ErrorCopy _copyFor(Object error) {
    if (error is UnauthorizedException) {
      return _ErrorCopy(
        icon: tokenReauth ? Icons.lock_outline : Icons.login,
        title: 'Sesi tidak valid',
        message: tokenReauth
            ? 'Token akses tidak berlaku. Perbarui token untuk melanjutkan.'
            : 'Sesi Anda telah berakhir. Masuk kembali untuk melanjutkan.',
        action: _ErrorAction.reauth,
        actionLabel: tokenReauth ? 'Perbarui token' : 'Masuk kembali',
      );
    }
    if (error is ReadOnlyException) {
      return const _ErrorCopy(
        icon: Icons.visibility_off_outlined,
        title: 'Perubahan tidak dapat dikirim',
        message: 'Layanan sedang tidak menerima perubahan. Coba lagi nanti.',
      );
    }
    if (error is ForbiddenException) {
      return const _ErrorCopy(
        icon: Icons.lock_outline,
        title: 'Akses tidak diizinkan',
        message:
            'Akun ini belum memiliki akses untuk tindakan tersebut. Hubungi perawat atau operator.',
      );
    }
    if (error is ValidationException) {
      return _ErrorCopy(
        icon: Icons.rule_outlined,
        title: 'Permintaan tidak valid',
        message: _messageOr(error.message, 'Data yang dikirim tidak valid.'),
      );
    }
    if (error is VersionConflictException ||
        error is IdempotencyConflictException ||
        error is BookingScheduleConflictException) {
      return _ErrorCopy(
        icon: Icons.refresh,
        title: 'Data perlu ditinjau kembali',
        message: (error as ApiException).message,
      );
    }
    if (error is RateLimitedException) {
      return const _ErrorCopy(
        icon: Icons.timer_outlined,
        title: 'Terlalu banyak permintaan',
        message: 'Tunggu sebentar, lalu coba lagi.',
      );
    }
    if (error is OutcomeUnknownException) {
      return const _ErrorCopy(
        icon: Icons.help_outline,
        title: 'Status belum pasti',
        message:
            'Hasil permintaan belum dapat dipastikan. Periksa status sebelum mengirim ulang.',
      );
    }
    if (error is InvalidFlowOutputException) {
      return const _ErrorCopy(
        icon: Icons.description_outlined,
        title: 'Hasil belum dapat ditampilkan',
        message:
            'Jawaban atau hasil pemrosesan belum dapat ditampilkan. Coba lagi nanti.',
        action: _ErrorAction.retry,
        actionLabel: 'Coba lagi',
      );
    }
    if (error is DependencyUnavailableException) {
      return const _ErrorCopy(
        icon: Icons.cloud_off_outlined,
        title: 'Layanan belum tersedia',
        message: 'Layanan belum tersedia. Coba muat kembali.',
        action: _ErrorAction.retry,
        actionLabel: 'Coba lagi',
      );
    }
    if (error is EmergencyGuidanceUnavailableException) {
      return const _ErrorCopy(
        icon: Icons.health_and_safety_outlined,
        title: 'Panduan darurat belum tersedia',
        message:
            'Informasi layanan darurat belum tersedia. Segera cari pertolongan medis langsung.',
      );
    }
    if (error is ProcessingFailedException) {
      return const _ErrorCopy(
        icon: Icons.error_outline,
        title: 'Proses belum selesai',
        message: 'Proses belum berhasil diselesaikan. Coba lagi nanti.',
        action: _ErrorAction.retry,
        actionLabel: 'Coba lagi',
      );
    }
    if (error is ServerConfigException) {
      return const _ErrorCopy(
        icon: Icons.settings_outlined,
        title: 'Layanan belum siap',
        message: 'Layanan belum dapat digunakan saat ini. Coba lagi nanti.',
      );
    }
    if (error is StreamUnavailableException) {
      return const _ErrorCopy(
        icon: Icons.cloud_off_outlined,
        title: 'Tidak bisa membuka aliran peristiwa',
        message:
            'Aliran peristiwa persetujuan tidak tersedia saat ini. Coba lagi.',
        action: _ErrorAction.retry,
        actionLabel: 'Coba lagi',
      );
    }
    if (error is EngineWarmingException) {
      return const _ErrorCopy(
        icon: Icons.hourglass_top_outlined,
        title: 'Layanan sedang menyiapkan, coba lagi',
        message:
            'Mesin pemrosesan belum siap. Tunggu sebentar, lalu coba lagi.',
        action: _ErrorAction.retry,
        actionLabel: 'Coba lagi',
      );
    }
    if (error is NetworkException) {
      return const _ErrorCopy(
        icon: Icons.wifi_off_outlined,
        title: 'Tidak bisa menghubungi server',
        message: 'Periksa koneksi Anda, lalu coba lagi.',
        action: _ErrorAction.retry,
        actionLabel: 'Coba lagi',
      );
    }
    if (error is NotFoundException) {
      return const _ErrorCopy(
        icon: Icons.search_off_outlined,
        title: 'Data tidak ditemukan',
        message: 'Data yang diminta tidak tersedia di server.',
      );
    }
    return const _ErrorCopy(
      icon: Icons.error_outline,
      title: 'Terjadi kesalahan',
      message: 'Terjadi kesalahan tak terduga. Coba lagi nanti.',
      action: _ErrorAction.retry,
      actionLabel: 'Coba lagi',
    );
  }

  String _messageOr(String message, String fallback) {
    return message.trim().isEmpty ? fallback : message;
  }
}

enum _ErrorAction { none, retry, reauth }

class _ErrorCopy {
  const _ErrorCopy({
    required this.icon,
    required this.title,
    required this.message,
    this.action = _ErrorAction.none,
    this.actionLabel = 'Coba lagi',
  });

  final IconData icon;
  final String title;
  final String message;
  final _ErrorAction action;
  final String actionLabel;
}
