import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/homecare.dart';
import '../../widgets/content_width.dart';
import '../../widgets/disclaimer_banner.dart';
import '../../widgets/error_state.dart';
import '../../widgets/patient_details.dart';
import 'homecare_providers.dart';

class HomecareScreen extends ConsumerWidget {
  const HomecareScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homecareCatalogProvider), page = state.valueOrNull;
    final content = switch (state) {
      AsyncData(:final value) => HomecareCatalogList(
        page: value,
        onRefresh: () => ref.read(homecareCatalogProvider.notifier).load(),
        onNext: () =>
            ref.read(homecareCatalogProvider.notifier).load(next: true),
      ),
      AsyncError(:final error) when page == null => ErrorState(
        error: error,
        onRetry: () => ref.invalidate(homecareCatalogProvider),
      ),
      AsyncError(:final error) => Column(
        children: [
          ErrorState(
            error: error,
            onRetry: () => ref.read(homecareCatalogProvider.notifier).load(),
          ),
          Expanded(
            child: HomecareCatalogList(
              page: page!,
              onRefresh: () =>
                  ref.read(homecareCatalogProvider.notifier).load(),
              onNext: () =>
                  ref.read(homecareCatalogProvider.notifier).load(next: true),
            ),
          ),
        ],
      ),
      AsyncLoading() when page != null => Column(
        children: [
          Semantics(
            liveRegion: true,
            child: const Text('Memperbarui katalog...'),
          ),
          Expanded(
            child: HomecareCatalogList(
              page: page,
              onRefresh: () =>
                  ref.read(homecareCatalogProvider.notifier).load(),
              onNext: () =>
                  ref.read(homecareCatalogProvider.notifier).load(next: true),
            ),
          ),
        ],
      ),
      _ => Semantics(
        liveRegion: true,
        child: const Text('Memuat layanan homecare...'),
      ),
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Homecare')),
      body: SafeArea(child: ContentWidth(child: content)),
    );
  }
}

class HomecareCatalogList extends StatelessWidget {
  const HomecareCatalogList({
    super.key,
    required this.page,
    required this.onRefresh,
    required this.onNext,
  });
  final ServicePage page;
  final VoidCallback onRefresh, onNext;
  @override
  Widget build(BuildContext context) => ListView.builder(
    padding: const EdgeInsetsDirectional.all(24),
    itemCount: page.services.length + 2,
    itemBuilder: (context, index) {
      if (index == 0) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DisclaimerBanner(compact: true),
            const SizedBox(height: 24),
            Text(
              'Layanan kunjungan perawat',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Simulasi DKI Jakarta (WIB). Jadwal menunggu konfirmasi; tidak ada petugas yang dikirim.',
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => context.go('/patient/bookings'),
              child: const Text('Buka booking saya'),
            ),
            const SizedBox(height: 24),
          ],
        );
      }
      if (index == page.services.length + 1) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (page.services.isEmpty)
              const Text(
                'Belum ada layanan aktif. Muat ulang katalog untuk memeriksa ketersediaan.',
              ),
            if (page.nextCursor != null)
              OutlinedButton(
                onPressed: onNext,
                child: const Text('Muat layanan berikutnya'),
              ),
            if (page.nextCursor != null) const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRefresh,
              child: const Text('Muat ulang katalog'),
            ),
          ],
        );
      }
      final service = page.services[index - 1];
      return Padding(
        padding: const EdgeInsetsDirectional.only(bottom: 16),
        child: Card(
          key: ValueKey(service.id),
          child: Padding(
            padding: const EdgeInsetsDirectional.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  service.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                PatientDetails(
                  title: 'Detail layanan',
                  children: [Text(service.description)],
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go(
                    '/patient/homecare/${Uri.encodeComponent(service.id)}/request',
                  ),
                  child: const Text('Ajukan kunjungan'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
