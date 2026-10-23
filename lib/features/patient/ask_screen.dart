import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../models/ask_answer.dart';
import '../../widgets/disclaimer_banner.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/source_chip.dart';
import '../../widgets/token_dialog.dart';

/// Patient-facing grounded Q&A screen (F5).
///
/// The server's answer is shown exactly as returned; this screen never
/// rewrites, softens, or embellishes a refusal. Provenance is surfaced with a
/// [SourceChip] and the untouched output stays available under "Teks verbatim".
class PatientAskScreen extends ConsumerStatefulWidget {
  const PatientAskScreen({super.key});

  @override
  ConsumerState<PatientAskScreen> createState() => _PatientAskScreenState();
}

class _PatientAskScreenState extends ConsumerState<PatientAskScreen> {
  static const String _emptyTitle = 'Belum ada pertanyaan';
  static const String _emptyMessage =
      'Tanyakan hal yang berkaitan dengan rencana tindak lanjut Anda.';

  final TextEditingController _queryController = TextEditingController();

  bool _submitting = false;
  AskAnswer? _answer;
  Object? _error;
  String? _validationError;
  String? _lastQuery;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _ask(String rawQuery) async {
    final String query = rawQuery.trim();
    if (query.isEmpty) {
      setState(() => _validationError = 'Tulis pertanyaan terlebih dahulu.');
      return;
    }

    final String patientId = ref.read(patientIdProvider);
    setState(() {
      _submitting = true;
      _error = null;
      _answer = null;
      _validationError = null;
      _lastQuery = query;
    });

    try {
      final AskAnswer answer = await ref
          .read(apiProvider)
          .ask(patientId: patientId, query: query);
      if (!mounted) {
        return;
      }
      setState(() {
        _answer = answer;
        _submitting = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error;
        _submitting = false;
      });
    }
  }

  void _retry() {
    final String? query = _lastQuery;
    if (query != null) {
      _ask(query);
    }
  }

  void _onQueryChanged(String _) {
    if (_validationError != null) {
      setState(() => _validationError = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String patientId = ref.watch(patientIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tanya Rencana')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: DisclaimerBanner(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Text(
                'ID pasien: $patientId',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(child: _buildAnswerArea()),
            _buildComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerArea() {
    if (_submitting) {
      return const Center(child: CircularProgressIndicator());
    }

    final Object? error = _error;
    if (error != null) {
      return ErrorState(
        error: error,
        onRetry: _retry,
        onReauth: () => showTokenDialog(context, ref),
      );
    }

    final AskAnswer? answer = _answer;
    if (answer != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: _AnswerCard(answer: answer),
      );
    }

    return const EmptyState(
      title: _emptyTitle,
      message: _emptyMessage,
      icon: Icons.question_answer_outlined,
    );
  }

  Widget _buildComposer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            controller: _queryController,
            minLines: 2,
            maxLines: 5,
            textInputAction: TextInputAction.newline,
            onChanged: _onQueryChanged,
            decoration: InputDecoration(
              labelText: 'Pertanyaan',
              hintText: 'Tanyakan hal-hal seputar rencana tindak lanjut Anda.',
              alignLabelWithHint: true,
              errorText: _validationError,
              errorMaxLines: 2,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _submitting ? null : () => _ask(_queryController.text),
            child: const Text('Tanya'),
          ),
        ],
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({required this.answer});

  final AskAnswer answer;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final String? source = answer.source;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.verified_outlined, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Jawaban',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              answer.text,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
            if (source != null) ...<Widget>[
              const SizedBox(height: 12),
              SourceChip(source: source),
            ],
            const SizedBox(height: 12),
            Text(
              'Jawaban berasal dari rencana yang disetujui. Bukan nasihat medis.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 4),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                leading: Icon(
                  Icons.notes_outlined,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
                title: Text(
                  'Teks verbatim',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                children: <Widget>[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      answer.rawText,
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
