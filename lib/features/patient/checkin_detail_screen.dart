import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/checkin_record.dart';
import '../../models/checkin_result.dart';
import '../../widgets/content_width.dart';
import '../../widgets/disclaimer_banner.dart';
import '../../widgets/error_state.dart';
import '../../widgets/risk_badge.dart';
import 'checkin_providers.dart';
import 'emergency_notice.dart';
import 'home_screen.dart';

class CheckinDetailScreen extends ConsumerWidget {
  const CheckinDetailScreen({required this.checkinId, super.key});
  final String checkinId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(checkinDetailProvider(checkinId)),
        cached = state.valueOrNull;
    void refresh() =>
        ref.read(checkinDetailProvider(checkinId).notifier).load();
    final content = switch (state) {
      AsyncData(:final value) => CheckinDetailContent(
        record: value,
        refreshing: state.isRefreshing,
        onRefresh: refresh,
      ),
      AsyncLoading() when cached != null => CheckinDetailContent(
        record: cached,
        refreshing: true,
        onRefresh: refresh,
      ),
      AsyncError(:final error) when cached != null => CheckinDetailContent(
        record: cached,
        error: error,
        onRefresh: refresh,
      ),
      AsyncError(:final error) => ErrorState(error: error, onRetry: refresh),
      _ => const OverviewLoading(),
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Detail laporan')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(24),
          child: ContentWidth(child: content),
        ),
      ),
    );
  }
}

class CheckinDetailContent extends StatelessWidget {
  const CheckinDetailContent({
    required this.record,
    required this.onRefresh,
    this.refreshing = false,
    this.error,
    super.key,
  });
  final CheckinRecord record;
  final VoidCallback onRefresh;
  final bool refreshing;
  final Object? error;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const DisclaimerBanner(compact: true),
      const SizedBox(height: 24),
      CheckinEvidence(record: record),
      const SizedBox(height: 24),
      if (refreshing) const Text('Memperbarui status laporan...'),
      if (error != null) ErrorState(error: error!, onRetry: onRefresh),
      OutlinedButton(
        onPressed: refreshing ? null : onRefresh,
        child: const Text('Muat ulang status laporan'),
      ),
    ],
  );
}

class CheckinEvidence extends StatelessWidget {
  const CheckinEvidence({required this.record, super.key});
  final CheckinRecord record;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (record.outcome case UrgentCheckinOutcome(:final reason)) ...[
        EmergencyNotice(reason: reason, alertEvidence: record.alertEvidence),
        const SizedBox(height: 24),
      ],
      Text('Laporan tersimpan', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      Text('Waktu kirim: ${record.createdLabel}'),
      const SizedBox(height: 12),
      Semantics(liveRegion: true, child: Text(record.processing.label)),
      const SizedBox(height: 12),
      Text(record.message),
      const SizedBox(height: 16),
      if (record.outcome case RoutineCheckinOutcome(:final result))
        RoutineReportContent(result: result),
      if (record.baseline?.applicable == false)
        const Text('Laporan ini dibuat sebelum pembaruan penilaian perawat.'),
    ],
  );
}

class RoutineReportContent extends StatelessWidget {
  const RoutineReportContent({required this.result, super.key});
  final CheckinResult result;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Hasil laporan', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: RiskBadge(tier: result.tier),
      ),
      if (result.action == 'trigger_plan_review') const SizedBox(height: 12),
      if (result.action == 'trigger_plan_review')
        const Text('Perlu tinjauan rencana oleh perawat.'),
      const SizedBox(height: 12),
      Text('Interval check-in demo: ${result.nextCheckinDays} hari.'),
    ],
  );
}
