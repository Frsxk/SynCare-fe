import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/escalation.dart';
import '../../widgets/content_width.dart';
import '../../widgets/disclaimer_banner.dart';
import '../../widgets/error_state.dart';
import 'alert_providers.dart';
import 'home_screen.dart';
import 'checkin_providers.dart';
import 'emergency_notice.dart';
import 'emergency_request.dart';

class AlertHistoryScreen extends ConsumerWidget {
  const AlertHistoryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(alertHistoryProvider),
        old = state.valueOrNull,
        notifier = ref.read(alertHistoryProvider.notifier);
    final content = switch (state) {
      AsyncData(:final value) => AlertHistoryList(
        page: value,
        header: const EmergencyRequestPanel(),
        onRefresh: () => notifier.load(),
        onNext: () => notifier.load(next: true),
      ),
      AsyncLoading() when old != null => AlertHistoryList(
        page: old,
        header: const EmergencyRequestPanel(),
        refreshing: true,
        onRefresh: () => notifier.load(),
        onNext: () => notifier.load(next: true),
      ),
      AsyncError(:final error) when old != null => AlertHistoryList(
        page: old,
        header: const EmergencyRequestPanel(),
        error: error,
        onRefresh: () => notifier.load(),
        onNext: () => notifier.load(next: true),
      ),
      AsyncError(:final error) => ListView(
        padding: const EdgeInsetsDirectional.all(24),
        children: [
          const EmergencyRequestPanel(),
          const SizedBox(height: 16),
          ErrorState(
            error: error,
            onRetry: () => ref.invalidate(alertHistoryProvider),
            onReauth: () => context.go('/account'),
          ),
        ],
      ),
      _ => ListView(
        padding: const EdgeInsetsDirectional.all(24),
        children: const [
          EmergencyRequestPanel(),
          SizedBox(height: 16),
          OverviewLoading(message: 'Memuat status tindak lanjut...'),
        ],
      ),
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Tindak lanjut saya')),
      body: SafeArea(child: ContentWidth(child: content)),
    );
  }
}

class AlertHistoryList extends StatelessWidget {
  const AlertHistoryList({
    required this.page,
    required this.onRefresh,
    required this.onNext,
    this.header,
    this.refreshing = false,
    this.error,
    super.key,
  });
  final EscalationPage page;
  final VoidCallback onRefresh, onNext;
  final Widget? header;
  final bool refreshing;
  final Object? error;
  @override
  Widget build(BuildContext context) => ListView.builder(
    padding: const EdgeInsetsDirectional.all(24),
    itemCount: page.alerts.length + 2,
    itemBuilder: (context, index) {
      if (index == 0) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (header != null) ...[header!, const SizedBox(height: 16)],
            const DisclaimerBanner(compact: true),
            const SizedBox(height: 16),
            const Text(
              'Status berikut mencatat proses tindak lanjut. Jangan menunggu balasan aplikasi untuk mencari pertolongan darurat.',
            ),
            if (refreshing)
              Semantics(
                liveRegion: true,
                child: const Text('Memperbarui status tindak lanjut...'),
              ),
            if (error != null) ErrorState(error: error!, onRetry: onRefresh),
          ],
        );
      }
      if (index == page.alerts.length + 1) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (page.alerts.isEmpty)
              const Text(
                'Belum ada alert tersimpan untuk akun Anda. Tidak adanya catatan ini bukan penilaian kondisi kesehatan Anda.',
              ),
            if (page.nextCursor != null)
              OutlinedButton(
                onPressed: refreshing ? null : onNext,
                child: const Text('Muat alert berikutnya'),
              ),
            if (page.nextCursor != null) const SizedBox(height: 12),
            OutlinedButton(
              onPressed: refreshing ? null : onRefresh,
              child: const Text('Muat ulang tindak lanjut'),
            ),
          ],
        );
      }
      final alert = page.alerts[index - 1];
      return Padding(
        key: ValueKey(alert.id),
        padding: const EdgeInsetsDirectional.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Status: ${alert.status.label}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              alert.isPatientRequest
                  ? 'Permintaan darurat: ${alert.reportedLabel}'
                  : 'Laporan: ${alert.reportedLabel}',
            ),
            Text(alert.reason),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => context.go(
                '/patient/alerts/${Uri.encodeComponent(alert.id)}',
              ),
              child: const Text('Buka detail tindak lanjut'),
            ),
          ],
        ),
      );
    },
  );
}

class AlertDetailScreen extends ConsumerWidget {
  const AlertDetailScreen({required this.alertId, super.key});
  final String alertId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(alertDetailProvider(alertId)),
        old = state.valueOrNull,
        notifier = ref.read(alertDetailProvider(alertId).notifier);
    final content = switch (state) {
      AsyncData(:final value) => AlertDetailContent(
        alert: value,
        onRefresh: () => notifier.load(),
        onOlder: () => notifier.load(older: true),
      ),
      AsyncLoading() when old != null => AlertDetailContent(
        alert: old,
        refreshing: true,
        onRefresh: () => notifier.load(),
        onOlder: () => notifier.load(older: true),
      ),
      AsyncError(:final error) when old != null => AlertDetailContent(
        alert: old,
        error: error,
        onRefresh: () => notifier.load(),
        onOlder: () => notifier.load(older: true),
      ),
      AsyncError(:final error) => ErrorState(
        error: error,
        onRetry: () => ref.invalidate(alertDetailProvider(alertId)),
        onReauth: () => context.go('/account'),
      ),
      _ => const OverviewLoading(message: 'Memuat status tindak lanjut...'),
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Detail tindak lanjut')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(24),
          child: ContentWidth(child: content),
        ),
      ),
    );
  }
}

class AlertDetailContent extends StatelessWidget {
  const AlertDetailContent({
    required this.alert,
    required this.onRefresh,
    required this.onOlder,
    this.refreshing = false,
    this.error,
    super.key,
  });
  final Escalation alert;
  final VoidCallback onRefresh, onOlder;
  final bool refreshing;
  final Object? error;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const DisclaimerBanner(compact: true),
      const SizedBox(height: 24),
      Text(
        'Status: ${alert.status.label}',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      Text(
        alert.isPatientRequest
            ? 'Permintaan darurat: ${alert.reportedLabel}'
            : 'Laporan: ${alert.reportedLabel}',
      ),
      const SizedBox(height: 16),
      Text(alert.reason),
      if (alert.acknowledgedLabel case final String label)
        Text('Diakui perawat: $label'),
      if (alert.resolvedLabel case final String label)
        Text(
          'Proses ditutup: $label. Status ini tidak menyatakan pasien sembuh.',
        ),
      const SizedBox(height: 16),
      const AlertGuidance(),
      const SizedBox(height: 24),
      Text(
        'Perkembangan tindak lanjut',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      for (final event in alert.timeline)
        Padding(
          key: ValueKey(event.id),
          padding: const EdgeInsetsDirectional.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(event.status.label),
              Text(event.recordedLabel),
              if (event.patientSummary case final String summary) Text(summary),
            ],
          ),
        ),
      if (refreshing)
        Semantics(
          liveRegion: true,
          child: const Text('Memperbarui status tindak lanjut...'),
        ),
      if (error != null) ErrorState(error: error!, onRetry: onRefresh),
      if (alert.timelineNextCursor != null)
        OutlinedButton(
          onPressed: refreshing ? null : onOlder,
          child: const Text('Muat riwayat sebelumnya'),
        ),
      OutlinedButton(
        onPressed: refreshing ? null : onRefresh,
        child: const Text('Muat ulang status tindak lanjut'),
      ),
      OutlinedButton(
        onPressed: () => context.go('/patient/alerts'),
        child: const Text('Kembali ke tindak lanjut saya'),
      ),
    ],
  );
}

class AlertGuidance extends ConsumerWidget {
  const AlertGuidance({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guidance = ref.watch(emergencyGuidanceProvider);
    return switch (guidance) {
      AsyncData(:final value) => GuidanceContent(guidance: value),
      AsyncError(:final error) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Segera cari pertolongan medis langsung. Jangan menunggu balasan aplikasi.',
          ),
          ErrorState(
            error: error,
            onRetry: () => ref.invalidate(emergencyGuidanceProvider),
          ),
        ],
      ),
      _ => Semantics(
        liveRegion: true,
        child: const Text(
          'Memuat panduan darurat terverifikasi. Jangan menunggu balasan aplikasi.',
        ),
      ),
    };
  }
}
