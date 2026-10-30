import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/homecare.dart';
import '../../widgets/content_width.dart';
import '../../widgets/disclaimer_banner.dart';
import '../../widgets/error_state.dart';
import 'homecare_providers.dart';

class BookingHistoryScreen extends ConsumerWidget {
  const BookingHistoryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookingHistoryProvider), old = state.valueOrNull;
    final notifier = ref.read(bookingHistoryProvider.notifier);
    final content = switch (state) {
      AsyncData(:final value) => BookingHistoryList(
        page: value,
        onRefresh: () => notifier.load(),
        onNext: () => notifier.load(next: true),
      ),
      AsyncLoading() when old != null => BookingHistoryList(
        page: old,
        refreshing: true,
        onRefresh: () => notifier.load(),
        onNext: () => notifier.load(next: true),
      ),
      AsyncError(:final error) when old != null => BookingHistoryList(
        page: old,
        error: error,
        onRefresh: () => notifier.load(),
        onNext: () => notifier.load(next: true),
      ),
      AsyncError(:final error) => ErrorState(
        error: error,
        onRetry: () => ref.invalidate(bookingHistoryProvider),
        onReauth: () => context.go('/account'),
      ),
      _ => Semantics(
        liveRegion: true,
        child: const Text('Memuat riwayat booking...'),
      ),
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Booking saya')),
      body: SafeArea(child: ContentWidth(child: content)),
    );
  }
}

class BookingHistoryList extends StatelessWidget {
  const BookingHistoryList({
    super.key,
    required this.page,
    required this.onRefresh,
    required this.onNext,
    this.refreshing = false,
    this.error,
  });
  final BookingPage page;
  final VoidCallback onRefresh, onNext;
  final bool refreshing;
  final Object? error;
  @override
  Widget build(BuildContext context) => ListView.builder(
    padding: const EdgeInsetsDirectional.all(24),
    itemCount: page.bookings.length + 2,
    itemBuilder: (context, index) {
      if (index == 0) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DisclaimerBanner(compact: true),
            const SizedBox(height: 16),
            if (refreshing)
              Semantics(
                liveRegion: true,
                child: const Text('Memperbarui riwayat booking...'),
              ),
            if (error != null) ErrorState(error: error!, onRetry: onRefresh),
            const SizedBox(height: 16),
          ],
        );
      }
      if (index == page.bookings.length + 1) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (page.bookings.isEmpty)
              const Text(
                'Belum ada booking tersimpan. Pilih layanan untuk membuat pengajuan.',
              ),
            if (page.nextCursor != null)
              OutlinedButton(
                onPressed: refreshing ? null : onNext,
                child: const Text('Muat booking berikutnya'),
              ),
            if (page.nextCursor != null) const SizedBox(height: 12),
            OutlinedButton(
              onPressed: refreshing ? null : onRefresh,
              child: const Text('Muat ulang booking'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.push('/patient/homecare'),
              child: const Text('Lihat layanan homecare'),
            ),
          ],
        );
      }
      final booking = page.bookings[index - 1];
      return Padding(
        key: ValueKey(booking.id),
        padding: const EdgeInsetsDirectional.only(bottom: 16),
        child: Card(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  booking.service.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text('Status: ${booking.status.label}'),
                Text('Dicatat: ${booking.createdLabel}'),
                if (booking.confirmedSlot case final BookingWindow slot)
                  Text(
                    '${booking.status == BookingStatus.scheduled ? 'Jadwal terkonfirmasi' : 'Riwayat jadwal'}: ${slot.startLabel}',
                  ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => context.push(
                    '/patient/bookings/${Uri.encodeComponent(booking.id)}',
                  ),
                  child: const Text('Buka detail booking'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
