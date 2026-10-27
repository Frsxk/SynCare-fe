import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/content_width.dart';
import '../../widgets/disclaimer_banner.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import 'home_screen.dart';
import 'question_providers.dart';
import 'qa_outcome_panel.dart';

class PatientAskScreen extends ConsumerWidget {
  const PatientAskScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(questionProvider),
        controller = ref.read(questionProvider.notifier);
    final content = switch (state) {
      AsyncData(:final value) when value != null => QaOutcomePanel(
        outcome: value,
        onRetry: () => controller.retry(),
      ),
      AsyncData() => const EmptyState(
        title: 'Belum ada pertanyaan',
        message:
            'Tanyakan hal yang berkaitan dengan rencana tindak lanjut Anda.',
        icon: Icons.question_answer_outlined,
      ),
      AsyncError(:final error) => ErrorState(
        error: error,
        onRetry: () => controller.retry(),
        onReauth: () => context.go('/account'),
      ),
      _ => const OverviewLoading(message: 'Menyiapkan jawaban...'),
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Tanya Rencana')),
      body: SafeArea(
        top: false,
        child: ContentWidth(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsetsDirectional.all(16),
                  child: DisclaimerBanner(compact: true),
                ),
                QuestionComposer(
                  key: ValueKey(controller),
                  busy: state.isLoading,
                  submit: controller.submit,
                ),
                Semantics(liveRegion: true, child: content),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class QuestionComposer extends StatefulWidget {
  const QuestionComposer({super.key, required this.busy, required this.submit});
  final bool busy;
  final Future<void> Function(String) submit;
  @override
  State<QuestionComposer> createState() => _QuestionComposerState();
}

class _QuestionComposerState extends State<QuestionComposer> {
  final query = TextEditingController();
  String? validation;
  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: query,
          minLines: 2,
          maxLines: 5,
          maxLength: 2000,
          enabled: !widget.busy,
          decoration: InputDecoration(
            labelText: 'Pertanyaan',
            hintText: 'Tanyakan hal seputar rencana tindak lanjut Anda.',
            counterText: '',
            errorText: validation,
            errorMaxLines: 3,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) {
            if (validation != null) setState(() => validation = null);
          },
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: widget.busy
              ? null
              : () {
                  if (query.text.trim().isEmpty) {
                    setState(
                      () => validation = 'Tulis pertanyaan terlebih dahulu.',
                    );
                    return;
                  }
                  FocusManager.instance.primaryFocus?.unfocus();
                  widget.submit(query.text);
                },
          child: const Text('Tanya'),
        ),
      ],
    ),
  );
}
