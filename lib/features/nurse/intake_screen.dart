import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/discharge_result.dart';
import '../../widgets/content_width.dart';
import '../../widgets/disclaimer_banner.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/risk_badge.dart';
import '../../widgets/token_dialog.dart';

/// Nurse intake: paste a discharge summary, score it with F1, and review the
/// server's risk breakdown before drafting a follow-up plan.
class NurseIntakeScreen extends ConsumerStatefulWidget {
  const NurseIntakeScreen({super.key});

  @override
  ConsumerState<NurseIntakeScreen> createState() => _NurseIntakeScreenState();
}

class _NurseIntakeScreenState extends ConsumerState<NurseIntakeScreen> {
  final TextEditingController _summaryController = TextEditingController();

  bool _submitting = false;
  Object? _error;

  @override
  void dispose() {
    _summaryController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String summary = _summaryController.text.trim();
    if (_submitting || summary.isEmpty) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final DischargeResult result = await ref
          .read(apiProvider)
          .discharge(summary);
      if (!mounted) {
        return;
      }
      ref.read(f1ResultProvider.notifier).state = result;
      setState(() {
        _submitting = false;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final DischargeResult? result = ref.watch(f1ResultProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Intake Perawat')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const DisclaimerBanner(),
                const SizedBox(height: 16),
                _buildForm(context),
                const SizedBox(height: 24),
                if (_submitting)
                  const _LoadingPanel()
                else if (_error != null)
                  SizedBox(
                    height: 360,
                    child: ErrorState(
                      error: _error!,
                      onRetry: _submit,
                      onReauth: () => showTokenDialog(context, ref),
                      tokenReauth: true,
                    ),
                  )
                else if (result == null)
                  const SizedBox(
                    height: 340,
                    child: EmptyState(
                      icon: Icons.fact_check_outlined,
                      title: 'Belum ada penilaian',
                      message:
                          'F1 mengekstrak episode rawat inap dari ringkasan '
                          'pulang, lalu memberi skor faktor risiko untuk '
                          'membantu penilaian awal. Tempel ringkasan di atas, '
                          'lalu tekan "Nilai ringkasan pulang".',
                    ),
                  )
                else
                  _ResultView(result: result),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Masukkan ringkasan pulang',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'F1 akan mengekstrak episode rawat inap dan memberi skor faktor '
              'risiko. Keluaran demo sintetis ini tidak tervalidasi klinis.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _summaryController,
              minLines: 8,
              maxLines: 16,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Ringkasan pulang pasien',
                hintText:
                    'Contoh: Pasien CHF NYHA III, pulang 2026-10-01, '
                    'furosemide 40mg harian, eGFR 52...',
                alignLabelWithHint: true,
                helperText:
                    'Minimal 6 baris. Semakin lengkap ringkasan, semakin '
                    'lengkap ekstraksi F1.',
                helperMaxLines: 2,
              ),
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _summaryController,
              builder:
                  (
                    BuildContext context,
                    TextEditingValue value,
                    Widget? child,
                  ) {
                    final bool canSubmit =
                        !_submitting && value.text.trim().isNotEmpty;
                    return FilledButton.icon(
                      onPressed: canSubmit ? _submit : null,
                      icon: Icon(
                        _submitting
                            ? Icons.hourglass_top_outlined
                            : Icons.fact_check_outlined,
                      ),
                      label: Text(
                        _submitting ? 'Menilai…' : 'Nilai ringkasan pulang',
                      ),
                    );
                  },
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 16),
          Text(
            'Menilai ringkasan pulang…',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.result});

  final DischargeResult result;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final List<MapEntry<String, RiskFactor>> factors = result
        .riskFactors
        .entries
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Card(
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
                        'Penilaian risiko F1',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(width: 8),
                    RiskBadge(tier: result.tier),
                  ],
                ),
                const SizedBox(height: 16),
                _DetailRow(label: 'Skor', value: '${result.score}'),
                const SizedBox(height: 8),
                _DetailRow(label: 'Label', value: _verbatim(result.label)),
                const SizedBox(height: 16),
                Text(
                  'Alasan penilaian',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _verbatim(result.rationale),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (factors.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Server tidak mengembalikan faktor risiko.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Faktor risiko', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Nilai, ambang, dan poin persis seperti dikembalikan F1.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  for (
                    int index = 0;
                    index < factors.length;
                    index++
                  ) ...<Widget>[
                    if (index > 0) const Divider(height: 24),
                    _FactorView(factor: factors[index].value),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        if (result.missingFields.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Field yang belum terisi',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final String field in result.missingFields)
                        Chip(label: Text(field)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        _NotValidatedBlock(result: result),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => context.go('/nurse/draft'),
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Lanjut ke draf'),
        ),
      ],
    );
  }
}

class _FactorView extends StatelessWidget {
  const _FactorView({required this.factor});

  final RiskFactor factor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          _humanizeFactorName(factor.name),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        _DetailRow(label: 'Nilai', value: _displayValue(factor.value)),
        const SizedBox(height: 4),
        _DetailRow(label: 'Ambang', value: _displayValue(factor.threshold)),
        const SizedBox(height: 4),
        _DetailRow(label: 'Poin', value: '${factor.points}'),
        const SizedBox(height: 4),
        _DetailRow(label: 'Terpenuhi', value: factor.met ? 'ya' : 'tidak'),
      ],
    );
  }
}

class _NotValidatedBlock extends StatelessWidget {
  const _NotValidatedBlock({required this.result});

  final DischargeResult result;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String marker =
        result.rawJson['not_clinically_validated']?.toString() ??
        (result.notClinicallyValidated ? 'true' : 'false');

    return Semantics(
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.highContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.highOutline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(
                  Icons.gpp_maybe_outlined,
                  size: 22,
                  color: AppTheme.onHighContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tidak tervalidasi klinis',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppTheme.onHighContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  'not_clinically_validated',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.onHighContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  marker,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.onHighContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              result.disclaimer,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.onHighContainer,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 132,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}

/// Turns a server snake_case factor key into a readable name without
/// translating or reinterpreting it.
String _humanizeFactorName(String name) {
  final String spaced = name.replaceAll('_', ' ').trim();
  if (spaced.isEmpty) {
    return name;
  }
  return '${spaced[0].toUpperCase()}${spaced.substring(1)}';
}

/// Renders a JSON scalar exactly as the server sent it; missing values get an
/// explicit label instead of invented content.
String _displayValue(Object? value) {
  if (value == null) {
    return 'Tidak tersedia';
  }
  final String text = value.toString();
  return text.isEmpty ? 'Tidak tersedia' : text;
}

String _verbatim(String value) {
  return value.isEmpty ? 'Tidak tersedia' : value;
}
