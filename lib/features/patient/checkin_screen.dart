import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/content_width.dart';
import '../../widgets/care_section.dart';
import '../../widgets/disclaimer_banner.dart';
import '../../widgets/error_state.dart';
import 'checkin_providers.dart';
import 'checkin_detail_screen.dart';

class PatientCheckinScreen extends ConsumerStatefulWidget {
  const PatientCheckinScreen({super.key});
  @override
  ConsumerState<PatientCheckinScreen> createState() =>
      _PatientCheckinScreenState();
}

class _PatientCheckinScreenState extends ConsumerState<PatientCheckinScreen> {
  late final TextEditingController _text;
  String? _validation;
  @override
  void initState() {
    super.initState();
    _text = TextEditingController(
      text: ref.read(checkinSubmitProvider.notifier).message,
    );
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    if (_text.text.trim().isEmpty) {
      setState(() => _validation = 'Tulis kondisi Anda terlebih dahulu.');
      return;
    }
    setState(() => _validation = null);
    FocusManager.instance.primaryFocus?.unfocus();
    ref.read(checkinSubmitProvider.notifier).submit(_text.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(checkinSubmitProvider);
    final status = switch (state) {
      CheckinUnavailable(:final error) => ErrorState(
        error: error,
        onReauth: () => context.go('/account'),
      ),
      CheckinDraft() => const Text(
        'Ceritakan keluhan atau perubahan kondisi Anda.',
      ),
      CheckinSending() => Semantics(
        liveRegion: true,
        child: const Text('Mengirim laporan...'),
      ),
      CheckinSendFailure(:final error) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ErrorState(error: error),
          const Text(
            'Status kiriman belum pasti. Periksa kiriman yang sama sebelum mencoba lagi.',
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () =>
                ref.read(checkinSubmitProvider.notifier).reconcile(),
            child: const Text('Periksa kiriman yang sama'),
          ),
        ],
      ),
      CheckinSaved(:final record, :final refreshing, :final error) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CareSection(child: CheckinEvidence(record: record)),
          const SizedBox(height: 16),
          if (refreshing) const Text('Memperbarui status laporan...'),
          if (error != null)
            ErrorState(
              error: error,
              onRetry: () => ref.read(checkinSubmitProvider.notifier).refresh(),
            ),
          OutlinedButton(
            onPressed: refreshing
                ? null
                : () => ref.read(checkinSubmitProvider.notifier).refresh(),
            child: const Text('Muat ulang status laporan'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              ref.read(checkinSubmitProvider.notifier).startNew();
              _text.clear();
            },
            child: const Text('Mulai laporan baru'),
          ),
        ],
      ),
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Check-in saya')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(24),
          child: ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const DisclaimerBanner(compact: true),
                const SizedBox(height: 24),
                status,
                const SizedBox(height: 24),
                if (state is! CheckinUnavailable && state is! CheckinSaved)
                  CareSection(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _text,
                          readOnly: state is! CheckinDraft,
                          minLines: 4,
                          maxLines: 6,
                          maxLength: 8000,
                          decoration: InputDecoration(
                            label: const Text(
                              'Kondisi Anda hari ini',
                              maxLines: 3,
                            ),
                            alignLabelWithHint: true,
                            counterText: '',
                            errorText: _validation,
                            errorMaxLines: 3,
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: state is CheckinDraft ? _submit : null,
                          child: const Text('Kirim check-in'),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => context.go('/patient/checkins'),
                  child: const Text('Buka riwayat laporan'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
