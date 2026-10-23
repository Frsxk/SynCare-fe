import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers.dart';
import '../../widgets/disclaimer_banner.dart';

enum AppRole {
  patient('patient', 'Saya Pasien'),
  nurse('nurse', 'Saya Perawat');

  const AppRole(this.storageValue, this.label);

  final String storageValue;
  final String label;
}

class RolePickerScreen extends ConsumerStatefulWidget {
  const RolePickerScreen({super.key, this.onSelected});

  final void Function(AppRole role)? onSelected;

  @override
  ConsumerState<RolePickerScreen> createState() => _RolePickerScreenState();
}

class _RolePickerScreenState extends ConsumerState<RolePickerScreen> {
  static const String _rolePreferenceKey = 'role';

  late final TextEditingController _patientIdController;
  bool _patientIdEdited = false;

  @override
  void initState() {
    super.initState();
    _patientIdController = TextEditingController(
      text: ref.read(patientIdProvider),
    );
  }

  @override
  void dispose() {
    _patientIdController.dispose();
    super.dispose();
  }

  Future<void> _selectRole(AppRole role) async {
    final patientId = _patientIdController.text.trim();
    if (patientId.isNotEmpty) {
      await ref.read(patientIdProvider.notifier).setPatientId(patientId);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rolePreferenceKey, role.storageValue);

    if (!mounted) return;
    final onSelected = widget.onSelected;
    if (onSelected != null) {
      onSelected(role);
      return;
    }
    context.go(switch (role) {
      AppRole.patient => '/patient/checkin',
      AppRole.nurse => '/nurse/intake',
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(patientIdProvider, (previous, next) {
      if (!_patientIdEdited && next != _patientIdController.text) {
        _patientIdController.text = next;
      }
    });

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const DisclaimerBanner(),
                  const SizedBox(height: 28),
                  Text(
                    'SynCare',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tindak lanjut pasca-rawat inap yang menyesuaikan tingkat risiko pasien.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Pilih peran Anda',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _RoleCard(
                    icon: Icons.favorite_border,
                    title: AppRole.patient.label,
                    description: 'Check-in dan rencana perawatan saya.',
                    onTap: () => _selectRole(AppRole.patient),
                  ),
                  const SizedBox(height: 16),
                  _RoleCard(
                    icon: Icons.medical_services_outlined,
                    title: AppRole.nurse.label,
                    description:
                        'Intake pasien, draf rencana, dan persetujuan.',
                    onTap: () => _selectRole(AppRole.nurse),
                  ),
                  const SizedBox(height: 32),
                  _DemoSettingsCard(
                    controller: _patientIdController,
                    onChanged: (_) => _patientIdEdited = true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoSettingsCard extends StatelessWidget {
  const _DemoSettingsCard({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pengaturan demo',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'ID Pasien demo',
                helperText: 'Dipakai lintas layar pasien dan draf perawat.',
                helperMaxLines: 2,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 30,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
