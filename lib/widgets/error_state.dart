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
  });

  final Object error;
  final VoidCallback? onRetry;
  final VoidCallback? onReauth;

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
                    icon: Icon(isAuth ? Icons.key_outlined : Icons.refresh),
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
      return const _ErrorCopy(
        icon: Icons.lock_outline,
        title: 'Sesi tidak valid',
        message: 'Token akses tidak berlaku. Perbarui token untuk melanjutkan.',
        action: _ErrorAction.reauth,
        actionLabel: 'Perbarui token',
      );
    }
    if (error is ReadOnlyException) {
      return const _ErrorCopy(
        icon: Icons.visibility_off_outlined,
        title: 'Server dalam mode baca-saja',
        message:
            'Aksi ini tidak tersedia selama server berjalan dalam mode '
            'baca-saja.',
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
    if (error is ServerConfigException) {
      return _ErrorCopy(
        icon: Icons.settings_outlined,
        title: 'Konfigurasi server bermasalah',
        message: _messageOr(
          error.message,
          'Server belum dikonfigurasi dengan benar.',
        ),
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
