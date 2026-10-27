import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/content_width.dart';
import '../../widgets/disclaimer_banner.dart';
import '../../widgets/error_state.dart';
import 'patient_providers.dart';
import 'home_screen.dart';

class PatientProfileScreen extends ConsumerWidget {
  const PatientProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ownOverviewProvider);
    final content = switch (state) {
      AsyncData(:final value) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DisclaimerBanner(compact: true),
          const SizedBox(height: 24),
          Text(
            value.profile.displayName,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            value.profile.recordedCondition ??
                'Belum ada kondisi yang dicatat perawat.',
          ),
          const SizedBox(height: 24),
          const Text('Hubungi perawat untuk memperbarui data profil.'),
        ],
      ),
      AsyncError(:final error) => ErrorState(
        error: error,
        onRetry: () => ref.invalidate(ownOverviewProvider),
      ),
      _ => const OverviewLoading(),
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Profil saya')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(24),
          child: ContentWidth(child: content),
        ),
      ),
    );
  }
}
