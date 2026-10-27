import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/session.dart';
import '../../widgets/content_width.dart';
import '../../widgets/care_section.dart';
import '../../widgets/disclaimer_banner.dart';
import 'session_controller.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final controller = ref.read(sessionControllerProvider.notifier);
    final content = switch (session) {
      SessionUnverified(:final failure) => RestoreSessionPanel(
        message: failure.message,
        onRetry: controller.restore,
        onLogout: controller.logout,
      ),
      SessionChecking() => LoginForm(busy: true, onSubmit: controller.login),
      SessionSignedOut(:final failure, :final revokeUnconfirmed) => LoginForm(
        busy: false,
        failure: failure?.message,
        revokeUnconfirmed: revokeUnconfirmed,
        onSubmit: controller.login,
      ),
      SessionAuthenticated() => const Text('Sesi telah diverifikasi.'),
    };
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(24),
          child: ContentWidth(
            maxWidth: 520,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const DisclaimerBanner(compact: true),
                const SizedBox(height: 32),
                Text(
                  'SynCare',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Masuk untuk mengakses tindak lanjut perawatan Anda.',
                ),
                const SizedBox(height: 24),
                CareSection(child: content),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LoginForm extends StatefulWidget {
  const LoginForm({
    required this.busy,
    required this.onSubmit,
    this.failure,
    this.revokeUnconfirmed = false,
    super.key,
  });
  final bool busy;
  final String? failure;
  final bool revokeUnconfirmed;
  final Future<void> Function(String, String) onSubmit;

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _identifier = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Masuk ke akun', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _identifier,
            decoration: const InputDecoration(
              labelText: 'Identitas akun',
              counterText: '',
              prefixIcon: Icon(Icons.person_outline),
            ),
            autofillHints: const [AutofillHints.username],
            textInputAction: TextInputAction.next,
            autocorrect: false,
            enableSuggestions: false,
            maxLength: 320,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _password,
            decoration: const InputDecoration(
              labelText: 'Kata sandi',
              counterText: '',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            autofillHints: const [AutofillHints.password],
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            maxLength: 128,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (!widget.busy) {
                widget.onSubmit(_identifier.text, _password.text);
              }
            },
          ),
          if (widget.failure case final String message) ...[
            const SizedBox(height: 16),
            Semantics(liveRegion: true, child: Text(message)),
          ],
          if (widget.revokeUnconfirmed) ...[
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: const Text(
                'Akses lokal telah ditutup. Pencabutan sesi di server belum terkonfirmasi.',
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: widget.busy
                ? null
                : () => widget.onSubmit(_identifier.text, _password.text),
            child: Text(widget.busy ? 'Memeriksa sesi...' : 'Masuk'),
          ),
          const SizedBox(height: 16),
          const Text(
            'Akun pasien diberikan oleh perawat berwenang. Hubungi perawat bila Anda belum memiliki akun.',
          ),
        ],
      ),
    );
  }
}

class RestoreSessionPanel extends StatelessWidget {
  const RestoreSessionPanel({
    required this.message,
    required this.onRetry,
    required this.onLogout,
    super.key,
  });
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Sesi belum terverifikasi',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 16),
      Semantics(liveRegion: true, child: Text(message)),
      const SizedBox(height: 24),
      FilledButton(onPressed: onRetry, child: const Text('Periksa sesi lagi')),
      const SizedBox(height: 12),
      OutlinedButton(
        onPressed: onLogout,
        child: const Text('Keluar dari perangkat ini'),
      ),
    ],
  );
}

class SessionAccountScreen extends ConsumerWidget {
  const SessionAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sessionControllerProvider);
    if (state is! SessionAuthenticated) return const LoginScreen();
    final principal = state.session.principal;
    return Scaffold(
      appBar: AppBar(title: const Text('Akun SynCare')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(24),
          child: ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const DisclaimerBanner(),
                const SizedBox(height: 24),
                Text(
                  'Akun saya',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                Text(
                  principal.role == 'patient'
                      ? 'Peran: Pasien'
                      : 'Peran: Perawat',
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sesi berlaku paling lama 24 jam sejak masuk. Masuk kembali diperlukan setelah sesi berakhir.',
                ),
                if (principal.role == 'nurse') ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Pengelolaan pasien tersedia melalui dashboard perawat.',
                  ),
                ],
                const SizedBox(height: 24),
                if (principal.role == 'patient')
                  TextButton(
                    onPressed: () => context.go('/patient/home'),
                    child: const Text('Ringkasan perawatan saya'),
                  ),
                OutlinedButton(
                  onPressed: () =>
                      ref.read(sessionControllerProvider.notifier).logout(),
                  child: const Text('Keluar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
