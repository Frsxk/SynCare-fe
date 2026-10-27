import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/patient.dart';
import '../../models/checkin_record.dart';
import '../../core/api_exception.dart';
import '../../widgets/content_width.dart';
import '../../widgets/care_section.dart';
import '../../widgets/disclaimer_banner.dart';
import '../../widgets/error_state.dart';
import 'patient_providers.dart';
import 'risk_summary.dart';
import 'emergency_notice.dart';

class PatientHomeScreen extends ConsumerWidget {
  const PatientHomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ownOverviewProvider), cached = state.valueOrNull;
    void refresh() => ref.invalidate(ownOverviewProvider);
    final content = switch (state) {
      AsyncData(:final value) => OverviewContent(
        overview: value,
        refreshing: state.isRefreshing,
        onRefresh: refresh,
      ),
      AsyncLoading() when cached != null => OverviewContent(
        overview: cached,
        refreshing: true,
        onRefresh: refresh,
      ),
      AsyncError(:final error)
          when cached != null &&
              error is! UnauthorizedException &&
              error is! ForbiddenException &&
              error is! NotFoundException =>
        OverviewContent(overview: cached, error: error, onRefresh: refresh),
      AsyncError(:final error) => ErrorState(error: error, onRetry: refresh),
      _ => const OverviewLoading(),
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Ringkasan saya')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(24),
          child: ContentWidth(child: content),
        ),
      ),
    );
  }
}

class OverviewContent extends StatelessWidget {
  const OverviewContent({
    required this.overview,
    required this.onRefresh,
    this.refreshing = false,
    this.error,
    super.key,
  });
  final PatientOverview overview;
  final VoidCallback onRefresh;
  final bool refreshing;
  final Object? error;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const DisclaimerBanner(compact: true),
      if (overview.latestReport?.outcome case UrgentCheckinOutcome(
        :final reason,
      )) ...[
        const SizedBox(height: 16),
        Text(
          'Waktu laporan mendesak terakhir: ${overview.latestReport!.createdLabel}',
        ),
        EmergencyNotice(
          reason: reason,
          alertEvidence: overview.latestReport!.alertEvidence,
        ),
      ],
      const SizedBox(height: 24),
      CareSection(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              overview.profile.displayName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.edit_note),
              onPressed: () => context.go('/patient/checkin'),
              label: const Text('Tulis check-in'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.person_outline),
              onPressed: () => context.go('/patient/profile'),
              label: const Text('Lihat profil saya'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      CareSection(child: RiskSummary(risk: overview.confirmedRisk)),
      const SizedBox(height: 16),
      if (refreshing)
        Semantics(
          liveRegion: true,
          child: const Text('Memperbarui ringkasan...'),
        ),
      if (error != null) ErrorState(error: error!, onRetry: onRefresh),
      TextButton.icon(
        icon: const Icon(Icons.refresh),
        onPressed: refreshing ? null : onRefresh,
        label: const Text('Muat ulang ringkasan'),
      ),
      const SizedBox(height: 24),
      CareSection(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Data perawatan',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (overview.latestReport case final CheckinRecord report) ...[
              Text('Laporan terakhir: ${report.createdLabel}'),
              Text(report.processing.label),
            ] else
              const Text('Belum ada laporan tersimpan.'),
            const SizedBox(height: 16),
            TextButton.icon(
              icon: const Icon(Icons.history),
              onPressed: () => context.go('/patient/checkins'),
              label: const Text('Buka riwayat laporan'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      CareAction(
        icon: Icons.home_work_outlined,
        title: 'Ajukan homecare',
        description: 'Kunjungan perawat dalam simulasi demo.',
        onTap: () => context.go('/patient/homecare'),
      ),
      const SizedBox(height: 12),
      CareAction(
        icon: Icons.support_agent,
        title: 'Buka status tindak lanjut',
        description: 'Lihat perkembangan laporan yang dieskalasi.',
        onTap: () => context.go('/patient/alerts'),
      ),
    ],
  );
}

class OverviewLoading extends StatefulWidget {
  const OverviewLoading({
    this.message = 'Memuat profil dan konfirmasi risiko...',
    super.key,
  });
  final String message;
  @override
  State<OverviewLoading> createState() => _OverviewLoadingState();
}

class _OverviewLoadingState extends State<OverviewLoading> {
  late final Timer _delay;
  bool _showShape = false;
  @override
  void initState() {
    super.initState();
    _delay = Timer(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _showShape = true);
    });
  }

  @override
  void dispose() {
    _delay.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DisclaimerBanner(compact: true),
        const SizedBox(height: 24),
        Text(widget.message),
        if (_showShape)
          const ExcludeSemantics(
            child: Column(
              children: [
                SizedBox(height: 24),
                Card(child: SizedBox(height: 56, width: double.infinity)),
                Card(child: SizedBox(height: 120, width: double.infinity)),
              ],
            ),
          ),
      ],
    ),
  );
}
