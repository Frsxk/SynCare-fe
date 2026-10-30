import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/checkin_record.dart';
import 'checkin_providers.dart';

class EmergencyNotice extends ConsumerWidget {
  const EmergencyNotice({
    required this.reason,
    required this.alertEvidence,
    this.source = 'F2',
    this.suppliedGuidance,
    super.key,
  });
  final String reason, alertEvidence;
  final String source;
  final EmergencyGuidance? suppliedGuidance;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guidance = suppliedGuidance == null
        ? ref.watch(emergencyGuidanceProvider)
        : AsyncData(suppliedGuidance!);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(16),
          child: DefaultTextStyle.merge(
            style: TextStyle(
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Perlu pertolongan segera',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
                const SizedBox(height: 12),
                Text(reason),
                const SizedBox(height: 12),
                Text(
                  source == 'F5'
                      ? 'Aplikasi tidak mengirim bantuan. Segera cari pertolongan medis.'
                      : alertEvidence == 'queued'
                      ? 'Lihat perkembangan laporan di status tindak lanjut. Aplikasi tidak mengirim bantuan.'
                      : 'Laporan belum terkonfirmasi. Segera cari pertolongan medis.',
                ),
                if (source == 'F2')
                  OutlinedButton(
                    onPressed: () => context.push('/patient/alerts'),
                    child: const Text('Buka status tindak lanjut'),
                  ),
                const SizedBox(height: 16),
                switch (guidance) {
                  AsyncData(:final value) => GuidanceContent(guidance: value),
                  _ => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Segera cari pertolongan medis langsung. Jangan menunggu balasan aplikasi.',
                      ),
                      const Text(
                        'Kontak darurat terverifikasi belum tersedia.',
                      ),
                      if (guidance.hasError)
                        OutlinedButton(
                          onPressed: () =>
                              ref.invalidate(emergencyGuidanceProvider),
                          child: const Text('Muat panduan lagi'),
                        ),
                    ],
                  ),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GuidanceContent extends StatelessWidget {
  const GuidanceContent({required this.guidance, super.key});
  final EmergencyGuidance guidance;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(guidance.content),
      const SizedBox(height: 12),
      const Text(
        'Demo hanya menampilkan informasi. Aplikasi tidak melakukan panggilan.',
      ),
      for (final contact in guidance.contacts)
        Text('${contact.label}: ${contact.number}'),
    ],
  );
}
