import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/discharge_result.dart';
import '../../models/plan_draft.dart';
import '../../widgets/content_width.dart';
import '../../widgets/disclaimer_banner.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/risk_badge.dart';
import '../../widgets/token_dialog.dart';

/// Nurse step 2: collect the follow-up date and hotline, then ask F3 for a
/// draft plan built on the unchanged F1 scored output.
class NurseDraftScreen extends ConsumerStatefulWidget {
  const NurseDraftScreen({super.key});

  @override
  ConsumerState<NurseDraftScreen> createState() => _NurseDraftScreenState();
}

class _NurseDraftScreenState extends ConsumerState<NurseDraftScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _patientIdController;
  late final TextEditingController _followupDateController;
  late final TextEditingController _hotlineController;

  DateTime? _followupDate;
  bool _submitting = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _patientIdController = TextEditingController(
      text: ref.read(patientIdProvider),
    );
    _followupDateController = TextEditingController();
    _hotlineController = TextEditingController();
  }

  @override
  void dispose() {
    _patientIdController.dispose();
    _followupDateController.dispose();
    _hotlineController.dispose();
    super.dispose();
  }

  String _isoDate(DateTime date) {
    return date.toIso8601String().split('T').first;
  }

  Future<void> _pickFollowupDate() async {
    final DateTime today = DateUtils.dateOnly(DateTime.now());
    final DateTime initial = DateUtils.dateOnly(
      today.add(const Duration(days: 7)),
    );
    final DateTime last = DateUtils.dateOnly(
      today.add(const Duration(days: 365)),
    );
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _followupDate ?? initial,
      firstDate: today,
      lastDate: last,
      helpText: 'Pilih tanggal tindak lanjut',
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _followupDate = picked;
      _followupDateController.text = _isoDate(picked);
    });
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }
    final DischargeResult? f1 = ref.read(f1ResultProvider);
    if (f1 == null) {
      return;
    }
    final FormState? form = _formKey.currentState;
    if (form != null && !form.validate()) {
      return;
    }

    final String patientId = _patientIdController.text.trim();
    final String hotline = _hotlineController.text.trim();
    final DateTime? followupDate = _followupDate;
    if (patientId.isEmpty || hotline.isEmpty || followupDate == null) {
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref.read(patientIdProvider.notifier).setPatientId(patientId);
      if (!mounted) {
        return;
      }
      final PlanDraft result = await ref
          .read(apiProvider)
          .draftPlan(
            patientId: patientId,
            followupDate: _isoDate(followupDate),
            hotline: hotline,
            f1ScoredOutput: f1,
          );
      if (!mounted) {
        return;
      }
      ref.read(draftResultProvider.notifier).state = result;
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error;
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final DischargeResult? f1 = ref.watch(f1ResultProvider);
    final PlanDraft? draft = ref.watch(draftResultProvider);
    final String patientId = ref.watch(patientIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Draf Tindak Lanjut')),
      body: ContentWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: DisclaimerBanner(),
            ),
            Expanded(
              child: _buildContent(
                context,
                f1: f1,
                draft: draft,
                patientId: patientId,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required DischargeResult? f1,
    required PlanDraft? draft,
    required String patientId,
  }) {
    if (f1 == null) {
      return _buildNeedsIntake(context);
    }
    if (_submitting) {
      return const _SubmittingState();
    }
    if (_error != null) {
      return ErrorState(
        error: _error!,
        onRetry: _submit,
        onReauth: () => showTokenDialog(context, ref),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: <Widget>[
        Text(
          'ID pasien aktif: $patientId',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        if (draft != null) ...<Widget>[
          _DraftResultCard(draft: draft),
          const SizedBox(height: 20),
        ],
        _buildFormCard(context, draft: draft),
      ],
    );
  }

  Widget _buildNeedsIntake(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: <Widget>[
        const EmptyState(
          title: 'Lakukan intake dulu',
          message:
              'Draf tindak lanjut membutuhkan hasil penilaian ringkasan '
              'pulang.',
          icon: Icons.assignment_outlined,
        ),
        const SizedBox(height: 8),
        Center(
          child: FilledButton.icon(
            key: const Key('draft-go-intake'),
            onPressed: () => context.go('/nurse/intake'),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Ke intake'),
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard(BuildContext context, {required PlanDraft? draft}) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isResubmit = draft != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                isResubmit ? 'Susun ulang draf' : 'Parameter draf',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Server tidak mengarang tanggal maupun hotline. Isi keduanya '
                'secara eksplisit sebelum menyusun draf.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('draft-patient-id'),
                controller: _patientIdController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'ID Pasien',
                  hintText: 'mis. demo-1',
                ),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'ID pasien wajib diisi.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('draft-followup-date'),
                controller: _followupDateController,
                readOnly: true,
                onTap: _pickFollowupDate,
                decoration: const InputDecoration(
                  labelText: 'Tanggal tindak lanjut',
                  hintText: 'YYYY-MM-DD',
                  suffixIcon: Icon(Icons.calendar_today_outlined),
                ),
                validator: (String? value) {
                  if (_followupDate == null) {
                    return 'Pilih tanggal tindak lanjut.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('draft-hotline'),
                controller: _hotlineController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Hotline',
                  hintText: 'mis. 1500-HOME',
                ),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Hotline wajib diisi.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('draft-submit'),
                onPressed: _submit,
                icon: const Icon(Icons.description_outlined),
                label: const Text('Susun draf'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubmittingState extends StatelessWidget {
  const _SubmittingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        liveRegion: true,
        label: 'Menyusun draf tindak lanjut',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Menyusun draf tindak lanjut…',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftResultCard extends StatelessWidget {
  const _DraftResultCard({required this.draft});

  final PlanDraft draft;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Card(
      key: const Key('draft-result'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Draf tindak lanjut',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                const SizedBox(width: 12),
                const _DraftLabel(),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Belum disetujui, wajib ditinjau tenaga kesehatan.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text('Rencana', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            Text(
              draft.planText.trim().isEmpty
                  ? 'Server tidak mengirim teks rencana.'
                  : draft.planText,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: <Widget>[
                Text('Tingkat risiko', style: theme.textTheme.labelLarge),
                RiskBadge(tier: draft.tier),
              ],
            ),
            if (draft.careIntensity.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              Text('Intensitas perawatan', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final String intensity in draft.careIntensity)
                    Chip(label: Text(intensity)),
                ],
              ),
            ],
            if (draft.status.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              Text('Status', style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              Text(draft.status, style: theme.textTheme.bodyMedium),
            ],
            if (draft.missingFacts.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              _MissingFactsWarning(facts: draft.missingFacts),
            ],
            if (draft.disclaimer.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  draft.disclaimer,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const Key('draft-to-approval'),
              onPressed: () => context.go('/nurse/approval'),
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Lanjut ke meja persetujuan'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftLabel extends StatelessWidget {
  const _DraftLabel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.neutralContainer,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.neutralOutline),
      ),
      child: Text(
        'DRAF',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppTheme.onNeutralContainer,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _MissingFactsWarning extends StatelessWidget {
  const _MissingFactsWarning({required this.facts});

  final List<String> facts;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.warningContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warningOutline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.info_outline,
                size: 18,
                color: AppTheme.onWarningContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Fakta yang belum lengkap',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppTheme.onWarningContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final String fact in facts)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(
                      Icons.circle,
                      size: 6,
                      color: AppTheme.onWarningContainer,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      fact,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.onWarningContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
