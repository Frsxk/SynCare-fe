import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_exception.dart';
import '../../models/homecare.dart';
import '../../widgets/content_width.dart';
import '../../widgets/disclaimer_banner.dart';
import '../../widgets/error_state.dart';
import 'homecare_providers.dart';
import 'booking_schedule_field.dart';

const bookingFieldLabels = <String, String>{
  'address': 'Alamat lengkap',
  'kelurahan': 'Kelurahan',
  'kecamatan': 'Kecamatan',
  'city': 'Kota/kabupaten administrasi',
  'date': 'Tanggal kunjungan',
  'start': 'Jam mulai (WIB)',
  'end': 'Jam selesai (WIB)',
  'note': 'Catatan tambahan (opsional)',
};

class BookingRequestScreen extends ConsumerStatefulWidget {
  const BookingRequestScreen({super.key, required this.serviceId});
  final String serviceId;
  @override
  ConsumerState<BookingRequestScreen> createState() =>
      _BookingRequestScreenState();
}

class _BookingRequestScreenState extends ConsumerState<BookingRequestScreen> {
  late final Map<String, TextEditingController> _fields;
  Object? _validation;
  @override
  void initState() {
    super.initState();
    final draft = ref.read(bookingSubmitProvider.notifier).draftFields;
    _fields = {
      for (final key in bookingFieldLabels.keys)
        key: TextEditingController(text: draft[key] ?? ''),
    };
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  void _submit() {
    try {
      final values = {
        for (final entry in _fields.entries) entry.key: entry.value.text,
      };
      final input = BookingInput.fromFields(widget.serviceId, values);
      setState(() => _validation = null);
      ref.read(bookingSubmitProvider.notifier).submit(input);
    } on ValidationException catch (error) {
      setState(() => _validation = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bookingSubmitProvider),
        catalog = ref.watch(homecareCatalogProvider);
    final services = catalog.valueOrNull?.services ?? <HomecareService>[];
    final service = services.where((s) => s.id == widget.serviceId).firstOrNull;
    final editable = state is BookingDraft;
    final feedback = switch (state) {
      BookingDraft(:final error) =>
        error == null
            ? const Text(
                'Pilih waktu kunjungan dalam WIB. Petugas akan meninjau permintaan Anda.',
              )
            : ErrorState(error: error),
      BookingSending() => Semantics(
        liveRegion: true,
        child: const Text('Mengirim pengajuan... Menunggu bukti penyimpanan.'),
      ),
      BookingUnknown(:final error) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ErrorState(error: error),
          const Text(
            'Hasil penyimpanan belum dapat dipastikan. Periksa pengajuan yang sama agar tidak membuat duplikat.',
          ),
          OutlinedButton(
            onPressed: () =>
                ref.read(bookingSubmitProvider.notifier).reconcile(),
            child: const Text('Periksa pengajuan yang sama'),
          ),
        ],
      ),
      BookingUnavailable(:final error) => ErrorState(
        error: error,
        onReauth: () => context.go('/account'),
      ),
      BookingSaved(:final booking) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BookingReceipt(booking: booking),
          OutlinedButton(
            onPressed: () => context.push(
              '/patient/bookings/${Uri.encodeComponent(booking.id)}',
            ),
            child: const Text('Lihat status booking'),
          ),
          OutlinedButton(
            onPressed: () {
              ref.read(bookingSubmitProvider.notifier).startNew();
              context.go('/patient/homecare');
            },
            child: const Text('Buat pengajuan baru'),
          ),
        ],
      ),
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Ajukan homecare')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(24),
          child: ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const DisclaimerBanner(compact: true),
                const SizedBox(height: 24),
                if (service != null)
                  Text(
                    service.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                const Text(
                  'Pengajuan simulasi DKI Jakarta. Waktu pilihan belum menjadi jadwal terkonfirmasi.',
                ),
                const SizedBox(height: 16),
                feedback,
                if (state is! BookingSaved && state is! BookingUnavailable) ...[
                  if (catalog.hasError && service == null)
                    ErrorState(
                      error: catalog.error!,
                      onRetry: () => ref.invalidate(homecareCatalogProvider),
                    )
                  else if (service == null)
                    Text(
                      catalog.isLoading
                          ? 'Memuat layanan...'
                          : 'Layanan ini tidak ada di katalog aktif. Kembali dan pilih layanan lain.',
                    ),
                  if (_validation != null) ErrorState(error: _validation!),
                  for (final entry in _fields.entries)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(top: 16),
                      child: BookingField(
                        field: entry.key,
                        controller: entry.value,
                        enabled: editable,
                        cities: service?.cities ?? const [],
                        onChanged: (value) =>
                            ref
                                    .read(bookingSubmitProvider.notifier)
                                    .draftFields[entry.key] =
                                value,
                      ),
                    ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: editable && service != null ? _submit : null,
                    child: const Text('Kirim pengajuan'),
                  ),
                ],
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/patient/homecare');
                    }
                  },
                  child: const Text('Kembali ke layanan'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BookingField extends StatelessWidget {
  const BookingField({
    super.key,
    required this.field,
    required this.controller,
    required this.enabled,
    required this.cities,
    required this.onChanged,
  });
  final String field;
  final TextEditingController controller;
  final bool enabled;
  final List<String> cities;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    if (field == 'date' || field == 'start' || field == 'end') {
      return BookingScheduleField(
        label: bookingFieldLabels[field]!,
        controller: controller,
        isDate: field == 'date',
        enabled: enabled,
        onChanged: onChanged,
      );
    }
    if (field == 'city') {
      return DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: cities.contains(controller.text) ? controller.text : null,
        decoration: InputDecoration(labelText: bookingFieldLabels[field]),
        items: cities
            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
            .toList(),
        onChanged: enabled
            ? (value) {
                if (value != null) {
                  controller.text = value;
                  onChanged(value);
                }
              }
            : null,
      );
    }
    return TextField(
      controller: controller,
      readOnly: !enabled,
      onChanged: onChanged,
      maxLines: field == 'address' || field == 'note' ? 3 : 1,
      maxLength: switch (field) {
        'address' => 1000,
        'note' => 2000,
        _ => 160,
      },
      decoration: InputDecoration(labelText: bookingFieldLabels[field]),
    );
  }
}

class BookingReceipt extends StatelessWidget {
  const BookingReceipt({super.key, required this.booking});
  final Booking booking;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Pengajuan tersimpan',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text('Status: ${booking.status.label}'),
        Text('Dicatat: ${booking.createdLabel}'),
        const SizedBox(height: 16),
        Text('Waktu pilihan: ${booking.startLabel} sampai ${booking.endLabel}'),
        Text('${booking.fullAddress}, ${booking.city}'),
        Text(
          booking.hasConfirmedSlot
              ? 'Lihat jadwal terkonfirmasi di status booking.'
              : 'Belum ada jadwal atau petugas terkonfirmasi. Petugas akan meninjau pengajuan Anda.',
        ),
      ],
    ),
  );
}
