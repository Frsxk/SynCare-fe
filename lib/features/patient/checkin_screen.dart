import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/checkin_result.dart';
import '../../widgets/disclaimer_banner.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/risk_badge.dart';
import '../../widgets/token_dialog.dart';

/// Patient check-in screen backed by F2.
///
/// The escalation red flag is a safety beat: when the server answers with
/// `action: escalate_immediately`, the reason is rendered verbatim in a red
/// card above every other result element, and no local scoring is applied.
class PatientCheckinScreen extends ConsumerStatefulWidget {
  const PatientCheckinScreen({super.key});

  @override
  ConsumerState<PatientCheckinScreen> createState() =>
      _PatientCheckinScreenState();
}

class _PatientCheckinScreenState extends ConsumerState<PatientCheckinScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _loading = false;
  String? _validationError;
  ApiException? _error;
  CheckinResult? _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) {
      return;
    }

    final String message = _controller.text.trim();
    if (message.isEmpty) {
      setState(() => _validationError = 'Tulis kondisi Anda terlebih dahulu.');
      return;
    }

    setState(() {
      _loading = true;
      _validationError = null;
      _error = null;
      _result = null;
    });

    try {
      final CheckinResult result = await ref
          .read(apiProvider)
          .checkin(patientId: ref.read(patientIdProvider), message: message);
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _result = result;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String patientId = ref.watch(patientIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Check-in Pasien')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const DisclaimerBanner(),
              const SizedBox(height: 20),
              Text(
                'ID pasien: $patientId',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              _buildOutcome(theme),
              const SizedBox(height: 20),
              _buildForm(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOutcome(ThemeData theme) {
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: <Widget>[
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 12),
            Text(
              'Mengirim check-in…',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final ApiException? error = _error;
    if (error != null) {
      return ErrorState(
        error: error,
        onRetry: _submit,
        onReauth: () => showTokenDialog(context, ref),
      );
    }

    final CheckinResult? result = _result;
    if (result != null) {
      return _buildResult(theme, result);
    }

    return const EmptyState(
      title: 'Belum ada check-in',
      message:
          'Tulis kondisi Anda hari ini. Perubahan gejala akan diteruskan ke '
          'tim perawat.',
      icon: Icons.monitor_heart_outlined,
    );
  }

  Widget _buildResult(ThemeData theme, CheckinResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (result.isEscalation) ...<Widget>[
          _EscalationCard(reason: result.reason),
          const SizedBox(height: 16),
        ] else ...<Widget>[
          _RoutineResultCard(result: result),
          const SizedBox(height: 16),
        ],
        _RawResponseCard(result: result),
      ],
    );
  }

  Widget _buildForm(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Kondisi hari ini', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              enabled: !_loading,
              minLines: 4,
              maxLines: 8,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              onChanged: (_) {
                if (_validationError != null) {
                  setState(() => _validationError = null);
                }
              },
              decoration: InputDecoration(
                labelText: 'Pesan check-in',
                hintText:
                    'Ceritakan gejala atau keluhan yang Anda rasakan hari '
                    'ini…',
                alignLabelWithHint: true,
                errorText: _validationError,
                errorMaxLines: 2,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loading ? null : _submit,
              icon: const Icon(Icons.send_outlined),
              label: Text(_loading ? 'Mengirim…' : 'Kirim check-in'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EscalationCard extends StatelessWidget {
  const _EscalationCard({this.reason});

  final String? reason;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? reasonText = reason;

    return Card(
      key: const Key('checkin-escalation-card'),
      color: AppTheme.highContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.highOutline, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 30,
                  color: AppTheme.onHighContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'PERLU TINDAKAN SEGERA',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppTheme.onHighContainer,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
            if (reasonText != null && reasonText.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                reasonText,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppTheme.onHighContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Check-in ini melewati penilaian risiko dan langsung diteruskan '
              'ke tim perawat.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.onHighContainer,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutineResultCard extends StatelessWidget {
  const _RoutineResultCard({required this.result});

  final CheckinResult result;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            RiskBadge(tier: result.tier),
            const SizedBox(height: 12),
            Text(
              result.isTierChange
                  ? 'Tier berubah: ${result.baselineTier ?? 'tidak diketahui'} → ${result.tier}'
                  : 'Tier saat ini: ${result.tier}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Skor risiko: ${result.score}',
              style: theme.textTheme.bodyMedium,
            ),
            if (result.nextCheckinDays != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                'Check-in berikutnya dalam ${result.nextCheckinDays} hari',
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if (result.adjustments.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              Text(
                'Penyesuaian skor',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              for (final CheckinAdjustment adjustment in result.adjustments)
                _AdjustmentRow(adjustment: adjustment),
            ],
            if (result.label.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              Text(
                result.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                ),
              ),
            ],
            if (result.disclaimer.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                result.disclaimer,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AdjustmentRow extends StatelessWidget {
  const _AdjustmentRow({required this.adjustment});

  final CheckinAdjustment adjustment;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool applied = adjustment.applied;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            applied ? Icons.check_circle_outline : Icons.remove_circle_outline,
            size: 18,
            color: applied ? scheme.primary : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(adjustment.condition, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 8,
                  children: <Widget>[
                    Text(
                      applied ? 'Diterapkan' : 'Tidak diterapkan',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '${adjustment.points} poin',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RawResponseCard extends StatelessWidget {
  const _RawResponseCard({required this.result});

  final CheckinResult result;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: const Text('Respons API mentah'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              const JsonEncoder.withIndent('  ').convert(result.raw),
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
