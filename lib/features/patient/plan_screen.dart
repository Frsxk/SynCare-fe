import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api_exception.dart';
import '../../core/providers.dart';
import '../../models/approved_plan.dart';
import '../../widgets/disclaimer_banner.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/risk_badge.dart';
import '../../widgets/token_dialog.dart';

/// Patient view of the plan a nurse approved for the current patient.
///
/// The server row is rendered verbatim: the tier, plan text, cadence, approval
/// metadata, and SATUSEHAT artifacts all come from `GET /plans/:patientId`.
/// A `404` is an honest "no approved plan yet" state, never an error.
class PatientPlanScreen extends ConsumerWidget {
  const PatientPlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String patientId = ref.watch(patientIdProvider);
    final AsyncValue<ApprovedPlanRecord> asyncPlan = ref.watch(
      approvedPlanProvider(patientId),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Rencana Saya')),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: DisclaimerBanner(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'ID Pasien: $patientId',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            Expanded(
              child: asyncPlan.when(
                loading: () => const _PlanLoading(),
                error: (Object error, StackTrace stackTrace) {
                  if (error is NotFoundException) {
                    return const EmptyState(
                      title: 'Belum ada rencana yang disetujui',
                      message:
                          'Rencana akan muncul di sini setelah perawat '
                          'menyetujui draf tindak lanjut.',
                      icon: Icons.description_outlined,
                    );
                  }
                  return ErrorState(
                    error: error,
                    onRetry: () =>
                        ref.invalidate(approvedPlanProvider(patientId)),
                    onReauth: () => showTokenDialog(context, ref),
                  );
                },
                data: (ApprovedPlanRecord record) =>
                    _PlanDetails(record: record),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanLoading extends StatelessWidget {
  const _PlanLoading();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 16),
          Text(
            'Memuat rencana…',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanDetails extends StatelessWidget {
  const _PlanDetails({required this.record});

  final ApprovedPlanRecord record;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ApprovedPlan plan = record.plan;
    final String? instruction = _patientInstruction(plan);
    final String? followupDate = instruction == null
        ? null
        : _isoDatePattern.firstMatch(instruction)?.group(0);
    final String? hotline = _hotline(instruction);
    final String status = plan.status.trim();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: RiskBadge(tier: plan.tier),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Rencana tindak lanjut',
            child: Text(
              plan.planText.trim().isEmpty ? '—' : plan.planText,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Intensitas perawatan',
            child: plan.careIntensity.isEmpty
                ? const _MissingValue()
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final String item in plan.careIntensity)
                        Chip(label: Text(item)),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Tindak lanjut',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _LabeledRow(
                  label: 'Instruksi pasien',
                  value: instruction ?? '—',
                ),
                _LabeledRow(
                  label: 'Tanggal tindak lanjut',
                  value: followupDate ?? '—',
                ),
                _LabeledRow(label: 'Hotline', value: hotline ?? '—'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Persetujuan',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _LabeledRow(
                  label: 'Disetujui pada',
                  value: _formatApprovalDate(record.approvedAt),
                ),
                _LabeledRow(
                  label: 'Catatan peninjau',
                  value: record.reviewerNote.trim().isEmpty
                      ? '—'
                      : record.reviewerNote,
                ),
                Text(
                  'Status: ${status.isEmpty ? '—' : status}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Persetujuan ditandai oleh keberadaan baris rencana ini, '
                  'bukan oleh nilai status di atas.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SatuseshatExpansion(plan: plan),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _LabeledRow extends StatelessWidget {
  const _LabeledRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(value, style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
        ],
      ),
    );
  }
}

class _MissingValue extends StatelessWidget {
  const _MissingValue();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Text(
      '—',
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _SatuseshatExpansion extends StatelessWidget {
  const _SatuseshatExpansion({required this.plan});

  final ApprovedPlan plan;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const Icon(Icons.data_object_outlined),
        title: const Text('Detail SATUSEHAT'),
        subtitle: Text(
          'FHIR-shaped output — bukan submission SATUSEHAT.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _JsonBlock(label: 'careplan', value: plan.satuseshat['careplan']),
          const SizedBox(height: 12),
          _JsonBlock(
            label: 'servicerequest',
            value: plan.satuseshat['servicerequest'],
          ),
          const SizedBox(height: 12),
          _JsonBlock(label: 'task', value: plan.satuseshat['task']),
        ],
      ),
    );
  }
}

class _JsonBlock extends StatelessWidget {
  const _JsonBlock({required this.label, required this.value});

  final String label;
  final Object? value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(10),
          ),
          child: SelectableText(
            _prettyJson(value),
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

final RegExp _isoDatePattern = RegExp(r'\d{4}-\d{2}-\d{2}');
final RegExp _hotlinePattern = RegExp(
  r'kontak rutin\s+(.+?)\.',
  caseSensitive: false,
);

String _formatApprovalDate(DateTime value) {
  return DateFormat('dd/MM/yyyy HH:mm').format(value.toLocal());
}

/// The only follow-up sentence the server provides.
String? _patientInstruction(ApprovedPlan plan) {
  final Object? serviceRequest = plan.satuseshat['servicerequest'];
  if (serviceRequest is! Map) {
    return null;
  }
  final Object? raw = serviceRequest['patientInstruction'];
  if (raw == null) {
    return null;
  }
  final String text = raw.toString().trim();
  return text.isEmpty ? null : text;
}

/// Hotline stated after `kontak rutin ` in the patient instruction.
String? _hotline(String? instruction) {
  if (instruction == null) {
    return null;
  }
  final String? value = _hotlinePattern
      .firstMatch(instruction)
      ?.group(1)
      ?.trim();
  return (value == null || value.isEmpty) ? null : value;
}

String _prettyJson(Object? value) {
  if (value == null) {
    return '—';
  }
  return const JsonEncoder.withIndent('  ').convert(value);
}
