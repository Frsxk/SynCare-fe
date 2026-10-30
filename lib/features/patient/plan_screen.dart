import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_exception.dart';
import '../../core/providers.dart';
import '../../models/approved_plan.dart';
import '../../widgets/content_width.dart';
import '../../widgets/disclaimer_banner.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/risk_badge.dart';
import '../../widgets/token_dialog.dart';
import '../../models/verified_care_plan.dart';
import 'approved_plan_providers.dart';
import 'home_screen.dart';
import 'plan_items.dart';

class PatientPlanScreen extends ConsumerWidget {
  const PatientPlanScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(verifiedPlansProvider),
        old = state.valueOrNull,
        controller = ref.read(verifiedPlansProvider.notifier);
    final content = switch (state) {
      AsyncData(:final value) => VerifiedPlansContent(
        page: value,
        onRefresh: () => controller.load(),
        onNext: () => controller.load(next: true),
      ),
      AsyncLoading() when old != null => VerifiedPlansContent(
        page: old,
        refreshing: true,
        onRefresh: () => controller.load(),
        onNext: () => controller.load(next: true),
      ),
      AsyncError(:final error) when old != null => VerifiedPlansContent(
        page: old,
        error: error,
        onRefresh: () => controller.load(),
        onNext: () => controller.load(next: true),
      ),
      AsyncError(:final error) => ErrorState(
        error: error,
        onRetry: () => ref.invalidate(verifiedPlansProvider),
        onReauth: () => context.go('/account'),
      ),
      _ => const OverviewLoading(message: 'Memuat rencana terverifikasi...'),
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Rencana Saya')),
      body: SafeArea(top: false, child: ContentWidth(child: content)),
    );
  }
}

class VerifiedPlansContent extends StatefulWidget {
  const VerifiedPlansContent({
    super.key,
    required this.page,
    required this.onRefresh,
    required this.onNext,
    this.refreshing = false,
    this.error,
  });
  final VerifiedPlanPage page;
  final VoidCallback onRefresh, onNext;
  final bool refreshing;
  final Object? error;
  @override
  State<VerifiedPlansContent> createState() => _VerifiedPlansContentState();
}

class _VerifiedPlansContentState extends State<VerifiedPlansContent> {
  String? selected;
  @override
  Widget build(BuildContext context) {
    final plans = widget.page.plans;
    final index = selected == null
            ? -1
            : plans.indexWhere((p) => p.id == selected),
        current = plans.isEmpty ? null : plans[index < 0 ? 0 : index];
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsetsDirectional.fromSTEB(16, 12, 16, 0),
            child: DisclaimerBanner(compact: true),
          ),
          if (widget.refreshing)
            Semantics(
              liveRegion: true,
              child: const Text('Memperbarui rencana terverifikasi...'),
            ),
          if (widget.error != null)
            ErrorState(error: widget.error!, onRetry: widget.onRefresh),
          Padding(
            padding: const EdgeInsetsDirectional.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: widget.refreshing ? null : widget.onRefresh,
                  child: const Text('Muat ulang rencana'),
                ),
                if (widget.page.nextCursor != null)
                  OutlinedButton(
                    onPressed: widget.refreshing ? null : widget.onNext,
                    child: const Text('Muat rencana sebelumnya'),
                  ),
              ],
            ),
          ),
          if (current == null)
            const EmptyState(
              title: 'Belum ada rencana terverifikasi',
              message: 'Rencana akan muncul setelah disetujui perawat.',
              icon: Icons.description_outlined,
            )
          else ...[
            if (plans.length > 1)
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
                child: DropdownButtonFormField<String>(
                  initialValue: current.id,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Riwayat persetujuan',
                  ),
                  items: plans
                      .map(
                        (p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(p.approvedLabel),
                        ),
                      )
                      .toList(),
                  onChanged: widget.refreshing
                      ? null
                      : (value) => setState(() => selected = value),
                ),
              ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
              child: Text(
                'Persetujuan terverifikasi: ${current.approvedLabel}.',
              ),
            ),
            if (!current.applicable)
              const Padding(
                padding: EdgeInsetsDirectional.all(16),
                child: Text(
                  'Rencana ini berasal dari sumber pulang sebelumnya. Hubungi perawat untuk meninjau sumber aktif.',
                ),
              ),
            _PlanDetails(record: current.record, embedded: true),
          ],
        ],
      ),
    );
  }
}

/// Patient view of the plan a nurse approved for the current patient.
///
/// Care instructions remain verbatim; integration artifacts stay out of the UI.
/// A `404` renders the empty state, not an error.
class LegacyPatientPlanScreen extends ConsumerWidget {
  const LegacyPatientPlanScreen({super.key});

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
        child: ContentWidth(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: DisclaimerBanner(),
                ),
                asyncPlan.when(
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
                      tokenReauth: true,
                    );
                  },
                  data: (ApprovedPlanRecord record) =>
                      _PlanDetails(record: record, embedded: true),
                ),
              ],
            ),
          ),
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
  const _PlanDetails({required this.record, this.embedded = false});

  final ApprovedPlanRecord record;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ApprovedPlan plan = record.plan;
    final String? instruction = _patientInstruction(plan);
    final String? followupDate = instruction == null
        ? null
        : _isoDatePattern.firstMatch(instruction)?.group(0);
    final String? hotline = _hotline(instruction);

    return SingleChildScrollView(
      physics: embedded ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: RiskBadge(tier: plan.tier),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Rencana tindak lanjut',
            child: _PlanItemList(
              items: planTextItems(plan.planText),
              semanticsLabel: 'Langkah rencana tindak lanjut',
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Intensitas perawatan',
            child: _PlanItemList(
              items: planStructuredItems(plan),
              semanticsLabel: 'Butir intensitas perawatan',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
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
                  value: instruction ?? 'Tidak tersedia',
                ),
                _LabeledRow(
                  label: 'Tanggal tindak lanjut',
                  value: followupDate ?? 'Tidak tersedia',
                ),
                _LabeledRow(
                  label: 'Hotline',
                  value: hotline ?? 'Tidak tersedia',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Persetujuan',
            child: _LabeledRow(
              label: 'Disetujui perawat (simulasi)',
              value: _formatApprovalDate(record.approvedAt),
            ),
          ),
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
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

class _PlanItemList extends StatelessWidget {
  const _PlanItemList({
    required this.items,
    required this.semanticsLabel,
    this.style,
  });

  final List<String> items;
  final String semanticsLabel;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _MissingValue();
    }
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: semanticsLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int index = 0; index < items.length; index++)
            Semantics(
              container: true,
              label: items[index],
              sortKey: OrdinalSortKey(index.toDouble()),
              child: ExcludeSemantics(
                child: Padding(
                  padding: EdgeInsetsDirectional.only(
                    bottom: index == items.length - 1 ? 0 : 8,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        width: 16,
                        child: Text(
                          '•',
                          style: style?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(child: Text(items[index], style: style)),
                    ],
                  ),
                ),
              ),
            ),
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
      'Tidak tersedia',
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
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
