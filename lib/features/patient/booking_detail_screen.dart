import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/homecare.dart';
import '../../widgets/content_width.dart';
import '../../widgets/disclaimer_banner.dart';
import '../../widgets/error_state.dart';
import 'homecare_providers.dart';

class BookingDetailScreen extends ConsumerStatefulWidget {
  const BookingDetailScreen({super.key, required this.bookingId});
  final String bookingId;
  @override
  ConsumerState<BookingDetailScreen> createState() =>
      _BookingDetailScreenState();
}

class _BookingDetailScreenState extends ConsumerState<BookingDetailScreen> {
  final _reason = TextEditingController();
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = bookingDetailProvider(widget.bookingId),
        state = ref.watch(provider);
    ref.listen(provider, (previous, next) {
      if (next is BookingReady &&
          next.feedback is CancelCommitted &&
          !(previous is BookingReady && previous.feedback is CancelCommitted)) {
        ref.invalidate(bookingHistoryProvider);
      }
    });
    final content = switch (state) {
      BookingDetailLoading() => Semantics(
        liveRegion: true,
        child: const Text('Memuat detail booking...'),
      ),
      BookingDetailFailure(:final error) => ErrorState(
        error: error,
        onRetry: () => ref.read(provider.notifier).load(),
        onReauth: () => context.go('/account'),
      ),
      BookingReady() => BookingDetailContent(
        state: state,
        reason: _reason,
        onRefresh: () => ref.read(provider.notifier).load(),
        onCancel: () => ref.read(provider.notifier).cancel(_reason.text),
        onReconcile: () => ref.read(provider.notifier).reconcile(),
      ),
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Detail booking')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(24),
          child: ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const DisclaimerBanner(compact: true),
                const SizedBox(height: 24),
                content,
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/patient/bookings');
                    }
                  },
                  child: const Text('Kembali ke booking saya'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BookingDetailContent extends StatelessWidget {
  const BookingDetailContent({
    super.key,
    required this.state,
    required this.reason,
    required this.onRefresh,
    required this.onCancel,
    required this.onReconcile,
  });
  final BookingReady state;
  final TextEditingController reason;
  final VoidCallback onRefresh, onCancel, onReconcile;
  @override
  Widget build(BuildContext context) {
    final booking = state.booking, feedback = state.feedback;
    final locked =
        state.refreshing ||
        feedback is CancelSending ||
        feedback is CancelUnknown;
    final result = switch (feedback) {
      CancelIdle() => const SizedBox.shrink(),
      CancelSending() => Semantics(
        liveRegion: true,
        child: const Text('Mengirim pembatalan... Menunggu bukti penyimpanan.'),
      ),
      CancelCommitted() => Semantics(
        liveRegion: true,
        child: const Text('Pembatalan tersimpan.'),
      ),
      CancelUnknown(:final error) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ErrorState(error: error),
          const Text(
            'Hasil pembatalan belum dapat dipastikan. Periksa pembatalan yang sama sebelum membuat perubahan lain.',
          ),
          OutlinedButton(
            onPressed: onReconcile,
            child: const Text('Periksa pembatalan yang sama'),
          ),
        ],
      ),
      CancelConflict(:final error) => Column(
        children: [
          ErrorState(error: error),
          const Text(
            'Status terbaru dibaca ulang. Pembatalan belum dinyatakan berhasil.',
          ),
        ],
      ),
      CancelRejected(:final error) => ErrorState(error: error),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          booking.service.name,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Semantics(
          liveRegion: true,
          child: Text(
            'Status: ${booking.status.label}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Text('Dicatat: ${booking.createdLabel}'),
        const SizedBox(height: 24),
        Text(
          'Waktu pilihan pasien',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text('${booking.startLabel} sampai ${booking.endLabel}'),
        const Text(
          'Pilihan ini terpisah dari jadwal yang dikonfirmasi perawat.',
        ),
        Text(
          '${booking.fullAddress}, ${booking.kelurahan}, ${booking.kecamatan}, ${booking.city}',
        ),
        if (booking.visitNote.isNotEmpty)
          Text('Catatan pengajuan: ${booking.visitNote}'),
        const SizedBox(height: 16),
        if (booking.confirmedSlot case final BookingWindow slot) ...[
          Text(
            booking.status == BookingStatus.scheduled
                ? 'Jadwal terkonfirmasi'
                : 'Riwayat jadwal',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text('${slot.startLabel} sampai ${slot.endLabel}'),
          Text('Perawat: ${booking.assignedStaff!.displayName}'),
          const SizedBox(height: 16),
        ] else
          const Text('Belum ada jadwal atau perawat terkonfirmasi.'),
        if (booking.status == BookingStatus.completed) ...[
          Text(
            'Kunjungan selesai',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text('Waktu aktual: ${booking.completedAt}'),
          Text('Catatan untuk Anda: ${booking.completionNote}'),
          const Text('Status selesai mencatat penutupan layanan simulasi.'),
          const SizedBox(height: 16),
        ],
        Text('Riwayat booking', style: Theme.of(context).textTheme.titleMedium),
        if (booking.timeline.isEmpty)
          const Text('Riwayat belum tersedia pada respons ini.'),
        for (final event in booking.timeline)
          Padding(
            key: ValueKey(event.id),
            padding: const EdgeInsetsDirectional.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  event.status.label,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(event.recordedLabel),
                if (event.reason != null) Text('Alasan: ${event.reason}'),
              ],
            ),
          ),
        const SizedBox(height: 24),
        result,
        if (booking.canCancel) ...[
          const SizedBox(height: 16),
          TextField(
            controller: reason,
            readOnly: locked,
            maxLines: 3,
            maxLength: 2000,
            decoration: const InputDecoration(labelText: 'Alasan pembatalan'),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: locked ? null : onCancel,
            child: const Text('Batalkan pengajuan'),
          ),
        ] else if (booking.status == BookingStatus.scheduled)
          const Text('Pembatalan booking terjadwal dikelola perawat.'),
        if (state.refreshing)
          Semantics(
            liveRegion: true,
            child: const Text('Memperbarui status booking...'),
          ),
        if (state.error != null)
          ErrorState(error: state.error!, onRetry: onRefresh),
        OutlinedButton(
          onPressed: state.refreshing || feedback is CancelSending
              ? null
              : onRefresh,
          child: const Text('Muat ulang status booking'),
        ),
      ],
    );
  }
}
