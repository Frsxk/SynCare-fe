import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncare_flutter/core/api_exception.dart';
import 'package:syncare_flutter/features/patient/checkin_providers.dart';
import 'package:syncare_flutter/features/patient/qa_outcome_panel.dart';
import 'package:syncare_flutter/models/ask_answer.dart';
import '../../helpers/pump_app.dart';

void main() {
  testWidgets(
    'qa_urgent_independent_of_alert: F5 reason warns without F2, alert queue or guessed contact',
    (tester) async {
      await tester.pumpWidget(
        wrapScreen(
          const SingleChildScrollView(
            child: QaOutcomePanel(
              outcome: QuestionEmergency('Nyeri dada sintetis.', null),
              onRetry: noop,
            ),
          ),
          overrides: [
            emergencyGuidanceProvider.overrideWith(
              (ref) => throw const NetworkException(),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Perlu pertolongan segera'), findsOneWidget);
      expect(find.text('Nyeri dada sintetis.'), findsOneWidget);
      expect(
        find.textContaining('Aplikasi tidak mengirim bantuan'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Segera cari pertolongan medis langsung.'),
        findsOneWidget,
      );
      expect(find.textContaining('119'), findsNothing);
      expect(find.text('Buka status tindak lanjut'), findsNothing);
      expect(find.text('Peringatan mendesak dari F2'), findsNothing);
    },
  );
  testWidgets(
    'retrieval failure is a typed error with explicit retry and no narrative answer',
    (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        wrapScreen(
          QaOutcomePanel(
            outcome: const QuestionFailure('retrieval_failed'),
            onRetry: () => retries++,
          ),
        ),
      );
      await tester.tap(find.text('Coba pertanyaan lagi'));
      expect(retries, 1);
      expect(
        find.text('Sumber jawaban belum dapat diambil. Coba lagi nanti.'),
        findsOneWidget,
      );
      expect(find.text('Jawaban F5'), findsNothing);
    },
  );
  test('urgent/error unknown or null outputs cannot become AskAnswer', () {
    for (final input in [
      null,
      {'kind': 'emergency', 'reason': '', 'guidance': null},
      {'kind': 'error', 'code': 'unknown'},
    ]) {
      expect(
        () => QuestionOutcome.fromJson(input, 'patient-a'),
        throwsA(isA<InvalidResponseException>()),
      );
    }
    expect(
      QuestionOutcome.fromJson({
        'kind': 'emergency',
        'reason': 'Sumber F5',
        'guidance': null,
      }, 'patient-a'),
      isA<QuestionEmergency>(),
    );
  });
}

void noop() {}
