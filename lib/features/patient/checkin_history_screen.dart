import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/checkin_record.dart';
import '../../widgets/content_width.dart';
import '../../widgets/disclaimer_banner.dart';
import '../../widgets/error_state.dart';
import 'checkin_providers.dart';
import 'home_screen.dart';

class CheckinHistoryScreen extends ConsumerWidget {
  const CheckinHistoryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(checkinHistoryProvider), cached = state.valueOrNull;
    void refresh() => ref.read(checkinHistoryProvider.notifier).load();
    final content = switch (state) {
      AsyncData(:final value) => CheckinHistoryList(
        page: value,
        refreshing: state.isRefreshing,
        onRefresh: refresh,
        onNext: () =>
            ref.read(checkinHistoryProvider.notifier).load(next: true),
      ),
      AsyncLoading() when cached != null => CheckinHistoryList(
        page: cached,
        refreshing: true,
        onRefresh: refresh,
        onNext: () =>
            ref.read(checkinHistoryProvider.notifier).load(next: true),
      ),
      AsyncError(:final error) when cached != null => CheckinHistoryList(
        page: cached,
        error: error,
        onRefresh: refresh,
        onNext: () =>
            ref.read(checkinHistoryProvider.notifier).load(next: true),
      ),
      AsyncError(:final error) => ErrorState(error: error, onRetry: refresh),
      _ => const OverviewLoading(),
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat laporan saya')),
      body: SafeArea(
        child: Center(child: ContentWidth(child: content)),
      ),
    );
  }
}

class CheckinHistoryList extends StatelessWidget {
  const CheckinHistoryList({
    required this.page,
    required this.onRefresh,
    required this.onNext,
    this.refreshing = false,
    this.error,
    super.key,
  });
  final CheckinPage page;
  final VoidCallback onRefresh, onNext;
  final bool refreshing;
  final Object? error;
  @override
  Widget build(BuildContext context) => ListView.builder(
    padding: const EdgeInsetsDirectional.all(24),
    itemCount: page.records.length + 2,
    itemBuilder: (context, index) {
      if (index == 0) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DisclaimerBanner(compact: true),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: refreshing ? null : onRefresh,
              child: const Text('Muat ulang riwayat'),
            ),
            const SizedBox(height: 12),
            if (refreshing) const Text('Memperbarui riwayat...'),
            if (error != null) ErrorState(error: error!, onRetry: onRefresh),
            if (page.records.isEmpty)
              const Text('Belum ada laporan tersimpan.'),
            OutlinedButton(
              onPressed: () => context.go('/patient/checkin'),
              child: const Text('Tulis check-in'),
            ),
          ],
        );
      }
      if (index == page.records.length + 1) {
        return page.nextCursor == null
            ? const SizedBox.shrink()
            : OutlinedButton(
                onPressed: refreshing ? null : onNext,
                child: const Text('Muat laporan berikutnya'),
              );
      }
      final report = page.records[index - 1];
      return CheckinHistoryRow(key: ValueKey(report.id), record: report);
    },
  );
}

class CheckinHistoryRow extends StatelessWidget {
  const CheckinHistoryRow({required this.record, super.key});
  final CheckinRecord record;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.symmetric(vertical: 12),
    child: OutlinedButton(
      onPressed: () => context.go('/patient/checkins/${record.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Text('Laporan ${record.createdAt}'),
          Text(record.processing.label),
          if (record.outcome is UrgentCheckinOutcome)
            const Text('Peringatan mendesak dari F2'),
          Text(record.message, maxLines: 3, overflow: TextOverflow.ellipsis),
        ],
      ),
    ),
  );
}
