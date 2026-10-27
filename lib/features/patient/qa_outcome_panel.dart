import 'package:flutter/material.dart';
import '../../models/ask_answer.dart';
import '../../widgets/source_chip.dart';
import 'emergency_notice.dart';

class QaOutcomePanel extends StatelessWidget {
  const QaOutcomePanel({
    super.key,
    required this.outcome,
    required this.onRetry,
  });
  final QuestionOutcome outcome;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => switch (outcome) {
    AskAnswer value => QuestionAnswerCard(answer: value),
    QuestionRefusal(:final text) => Padding(
      padding: const EdgeInsetsDirectional.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Di luar cakupan rencana',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Text(text),
        ],
      ),
    ),
    QuestionEmergency(:final reason, :final guidance) => EmergencyNotice(
      reason: reason,
      alertEvidence: 'not_created',
      source: 'F5',
      suppliedGuidance: guidance,
    ),
    QuestionFailure value => Padding(
      padding: const EdgeInsetsDirectional.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(value.message),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('Coba pertanyaan lagi'),
          ),
        ],
      ),
    ),
  };
}

class QuestionAnswerCard extends StatelessWidget {
  const QuestionAnswerCard({super.key, required this.answer});
  final AskAnswer answer;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.all(16),
    child: Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Jawaban', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(answer.patientText),
            const SizedBox(height: 16),
            Text(
              'Sumber jawaban',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (var i = 0; i < answer.citations.length; i++)
              QuestionSource(citation: answer.citations[i], number: i + 1),
          ],
        ),
      ),
    ),
  );
}

class QuestionSource extends StatelessWidget {
  const QuestionSource({
    super.key,
    required this.citation,
    required this.number,
  });
  final QuestionCitation citation;
  final int number;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(top: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SourceChip(
          source: citation.approved
              ? '$number. Rencana perawatan'
              : '$number. Materi edukasi',
        ),
        const SizedBox(height: 6),
        Text(
          citation.approved
              ? 'Rencana disetujui perawat (simulasi).'
              : 'Materi edukasi, belum disetujui perawat.',
        ),
      ],
    ),
  );
}
