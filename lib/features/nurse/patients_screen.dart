import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../models/approved_plan.dart';
import '../../widgets/content_width.dart';
import '../../widgets/disclaimer_banner.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/risk_badge.dart';
import '../../widgets/token_dialog.dart';

/// Screen for nurses to view approved post-discharge plans and the audit trail.
///
/// Data is fetched via [plansProvider] and rendered verbatim without any client
/// scoring, tier calculation, or edit affordances.
class NursePatientsScreen extends ConsumerWidget {
  const NursePatientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<PlansResponse> asyncPlans = ref.watch(plansProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pasien & Audit'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
            onPressed: () => ref.invalidate(plansProvider),
          ),
        ],
      ),
      body: SafeArea(
        child: ContentWidth(
          child: Column(
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: DisclaimerBanner(),
              ),
              Expanded(
                child: asyncPlans.when(
                  loading: () => const _LoadingView(),
                  error: (Object error, StackTrace stackTrace) => ErrorState(
                    error: error,
                    onRetry: () => ref.invalidate(plansProvider),
                    onReauth: () => showTokenDialog(context, ref),
                    tokenReauth: true,
                  ),
                  data: (PlansResponse response) {
                    final List<ApprovedPlanRecord> plans = response.plans;
                    final List<AuditEntry> audit = response.audit;

                    if (plans.isEmpty && audit.isEmpty) {
                      return const EmptyState(
                        title: 'Belum ada rencana disetujui',
                        message:
                            'Rencana yang disetujui perawat akan muncul di sini '
                            'beserta jejak auditnya.',
                        icon: Icons.folder_open_outlined,
                      );
                    }

                    return _PlansAndAuditView(plans: plans, audit: audit);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Memuat daftar rencana…',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlansAndAuditView extends StatelessWidget {
  const _PlansAndAuditView({required this.plans, required this.audit});

  final List<ApprovedPlanRecord> plans;
  final List<AuditEntry> audit;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Rencana disetujui',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (plans.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Belum ada rencana disetujui.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final ApprovedPlanRecord record in plans)
            _PlanCard(record: record),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Jejak audit',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (audit.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Belum ada jejak audit.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final AuditEntry entry in audit) _AuditListTile(entry: entry),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.record});

  final ApprovedPlanRecord record;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final String formattedDate = DateFormat(
      'dd/MM/yyyy HH:mm',
    ).format(record.approvedAt.toLocal());
    final String note = record.reviewerNote.trim().isEmpty
        ? 'Tidak tersedia'
        : record.reviewerNote;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        record.patientId,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formattedDate,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                RiskBadge(tier: record.plan.tier),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              record.plan.planText,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Catatan peninjau: ',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Expanded(
                  child: Text(
                    note,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AuditListTile extends StatelessWidget {
  const _AuditListTile({required this.entry});

  final AuditEntry entry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final String formattedDate = DateFormat(
      'dd/MM/yyyy HH:mm',
    ).format(entry.timestamp.toLocal());

    return ListTile(
      leading: Icon(Icons.history, color: scheme.onSurfaceVariant),
      title: Text(
        entry.action,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 2),
          Text(
            entry.actor,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: 2),
          Text(
            formattedDate,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
