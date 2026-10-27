import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncare_flutter/core/api_exception.dart';
import 'package:syncare_flutter/features/patient/ask_screen.dart';
import 'package:syncare_flutter/features/patient/question_providers.dart';
import 'package:syncare_flutter/features/patient/qa_outcome_panel.dart';
import 'package:syncare_flutter/models/ask_answer.dart';
import 'package:syncare_flutter/widgets/disclaimer_banner.dart';
import 'package:syncare_flutter/widgets/source_chip.dart';
import '../../helpers/error_fixture.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

const refusal =
    'Maaf, pertanyaan itu di luar cakupan rencana Anda. Silakan tanyakan ke perawat Anda atau hubungi hotline.';
Map<String, dynamic> questionFixture() {
  final citations = [
    {
      'id': 'patient-a:plan_text#1',
      'label': 'rencana_disetujui_workflow_sintetis',
      'provenance': 'approved_plan',
      'quote': 'Aktivitas sumber satu.',
    },
    {
      'id': 'hf-aftercare:section:0#1',
      'label': 'draf_edukasi_tidak_disetujui',
      'provenance': 'unapproved_education',
      'quote': 'Edukasi sumber dua.',
    },
    {
      'id': 'patient-a:care_intensity:0#1',
      'label': 'rencana_disetujui_workflow_sintetis',
      'provenance': 'approved_plan',
      'quote': 'Aktivitas sumber tiga.',
    },
  ];
  return {
    'kind': 'answer',
    'text':
        'Disclaimer sintetis. ${citations.map((c) => '${c['quote']} [${c['id']} | ${c['label']}]').join(' ')}',
    'disclaimer': 'Disclaimer sintetis.',
    'citations': citations,
  };
}

void main() {
  Future<void> pump(
    WidgetTester tester,
    FakeSyncareApi api, {
    String? patient = 'patient-a',
  }) async {
    await tester.pumpWidget(
      wrapScreen(
        const PatientAskScreen(),
        overrides: [
          questionProvider.overrideWith(
            (ref) => QuestionController(api, patient),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.tap(find.text('Tanya'));
    await tester.pump();
  }

  testWidgets(
    'a second explicit question after an answer sends a new request from the same composer',
    (tester) async {
      var calls = 0;
      final api = FakeSyncareApi()
        ..onAsk = ({required patientId, required query}) async {
          calls++;
          return calls == 1
              ? QuestionOutcome.fromJson(questionFixture(), patientId)
              : const QuestionRefusal(refusal);
        };
      await pump(tester, api);
      await send(tester, 'rencana');
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      await send(tester, 'pertanyaan kedua');
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text(refusal), findsOneWidget);
    },
  );

  test(
    'typed parser preserves all source references and rejects foreign source or raw/unknown outcomes',
    () {
      final answer =
          QuestionOutcome.fromJson(questionFixture(), 'patient-a') as AskAnswer;
      expect(answer.citations.length, 3);
      expect(answer.citations[1].approved, false);
      expect(answer.text, questionFixture()['text']);
      for (final value in [
        {'kind': 'unexpected'},
        {'kind': 'error', 'code': 'retrieval_failed', 'reason': 'PRIVATE'},
        'raw JSON',
        {
          'kind': 'answer',
          'text': 'no citations',
          'disclaimer': 'demo',
          'citations': [],
        },
      ]) {
        expect(
          () => QuestionOutcome.fromJson(value, 'patient-a'),
          throwsA(isA<InvalidResponseException>()),
        );
      }
      expect(
        () => QuestionOutcome.fromJson(questionFixture(), 'patient-b'),
        throwsA(isA<InvalidResponseException>()),
      );
    },
  );
  testWidgets(
    'shows disclaimer, empty prompt and composer without a fallback patient caption',
    (tester) async {
      await pump(tester, FakeSyncareApi());
      expect(find.byType(DisclaimerBanner), findsOneWidget);
      expect(find.text('Belum ada pertanyaan'), findsOneWidget);
      expect(find.textContaining('ID pasien:'), findsNothing);
      expect(find.text('Tanya'), findsOneWidget);
    },
  );
  testWidgets('blank question does not call API', (tester) async {
    var calls = 0;
    final api = FakeSyncareApi()
      ..onAsk = ({required patientId, required query}) async {
        calls++;
        return const QuestionRefusal(refusal);
      };
    await pump(tester, api);
    await send(tester, '   ');
    expect(calls, 0);
    expect(find.text('Tulis pertanyaan terlebih dahulu.'), findsOneWidget);
  });
  testWidgets(
    'pending blocks duplicate submit and publishes only the completed typed result',
    (tester) async {
      var calls = 0;
      final completer = Completer<QuestionOutcome>(),
          api = FakeSyncareApi()
            ..onAsk = ({required patientId, required query}) {
              calls++;
              expect(patientId, 'patient-a');
              expect(query, 'rencana');
              return completer.future;
            };
      await pump(tester, api);
      await send(tester, ' rencana ');
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(calls, 1);
      completer.complete(const QuestionRefusal(refusal));
      await tester.pumpAndSettle();
      expect(find.text(refusal), findsOneWidget);
    },
  );
  testWidgets(
    'qa_multiple_provenance: three citations render and education is explicitly unapproved',
    (tester) async {
      final api = FakeSyncareApi()
        ..onAsk = ({required patientId, required query}) async =>
            QuestionOutcome.fromJson(questionFixture(), patientId);
      await pump(tester, api);
      await send(tester, 'rencana');
      await tester.pumpAndSettle();
      final outcome =
          QuestionOutcome.fromJson(questionFixture(), 'patient-a') as AskAnswer;
      expect(find.text(outcome.patientText), findsOneWidget);
      expect(outcome.patientText, contains('Aktivitas sumber satu. [1]'));
      expect(outcome.patientText, contains('Edukasi sumber dua. [2]'));
      expect(outcome.rawText, questionFixture()['text']);
      expect(find.byType(SourceChip), findsNWidgets(3));
      expect(
        find.text('Materi edukasi, belum disetujui perawat.'),
        findsOneWidget,
      );
      expect(find.textContaining('patient-a:'), findsNothing);
      expect(
        find.textContaining('rencana_disetujui_workflow_sintetis'),
        findsNothing,
      );
    },
  );
  testWidgets(
    'refusal stays exactly verbatim without an approved-answer label',
    (tester) async {
      await pump(
        tester,
        FakeSyncareApi()
          ..onAsk = ({required patientId, required query}) async =>
              const QuestionRefusal(refusal),
      );
      await send(tester, 'di luar cakupan');
      await tester.pumpAndSettle();
      expect(find.text(refusal), findsOneWidget);
      expect(find.byType(SourceChip), findsNothing);
      expect(find.text('Jawaban F5'), findsNothing);
    },
  );
  testWidgets(
    'nested 502 invalid flow output never claims the approval stream failed',
    (tester) async {
      final api = FakeSyncareApi()
        ..onAsk = ({required patientId, required query}) async => throw apiExceptionForStatus(
          502,
          nestedErrorBody(
            'invalid_flow_output',
            message: 'Hasil pemrosesan tidak dapat ditampilkan.',
            requestId: 'req-qa-flow',
          ),
        );
      await pump(tester, api);
      await send(tester, 'pertanyaan');
      await tester.pumpAndSettle();
      expect(find.text('Hasil belum dapat ditampilkan'), findsOneWidget);
      expect(
        find.textContaining('Jawaban atau hasil pemrosesan'),
        findsOneWidget,
      );
      expect(find.textContaining('aliran peristiwa'), findsNothing);
      expect(find.text('Tidak bisa membuka aliran peristiwa'), findsNothing);
      expect(find.textContaining('approval'), findsNothing);
    },
  );
  testWidgets(
    'nested 502 outcome unknown is distinct and has no blind resend',
    (tester) async {
      final api = FakeSyncareApi()
        ..onAsk = ({required patientId, required query}) async => throw apiExceptionForStatus(
          502,
          nestedErrorBody(
            'outcome_unknown',
            message: 'Hasil permintaan belum dapat dipastikan.',
            requestId: 'req-qa-outcome',
          ),
        );
      await pump(tester, api);
      await send(tester, 'pertanyaan');
      await tester.pumpAndSettle();
      expect(find.text('Status belum pasti'), findsOneWidget);
      expect(find.textContaining('aliran peristiwa'), findsNothing);
      expect(find.text('Coba lagi'), findsNothing);
    },
  );
  testWidgets(
    'network error offers explicit retry of unchanged query, without automatic inference',
    (tester) async {
      var calls = 0;
      final api = FakeSyncareApi()
        ..onAsk = ({required patientId, required query}) async {
          calls++;
          expect(query, 'pertanyaan lama');
          if (calls == 1) throw const NetworkException();
          return const QuestionRefusal(refusal);
        };
      await pump(tester, api);
      await send(tester, 'pertanyaan lama');
      await tester.pumpAndSettle();
      expect(calls, 1);
      await tester.ensureVisible(find.text('Coba lagi'));
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text(refusal), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'pertanyaan lama',
      );
    },
  );
  test(
    'own controller never uses fallback identity and disposed late answer cannot publish',
    () async {
      var calls = 0;
      final completer = Completer<QuestionOutcome>(),
          api = FakeSyncareApi()
            ..onAsk = ({required patientId, required query}) {
              calls++;
              return completer.future;
            };
      final absent = QuestionController(api, null);
      await absent.submit('query');
      expect(calls, 0);
      expect(absent.state.hasError, true);
      absent.dispose();
      final controller = QuestionController(api, 'patient-a'),
          request = controller.submit('query');
      await controller.submit('duplicate');
      expect(calls, 1);
      controller.dispose();
      completer.complete(const QuestionRefusal(refusal));
      await request;
    },
  );
  testWidgets(
    'long source provenance at320/text200 remains scrollable without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        wrapScreen(
          SingleChildScrollView(
            child: QaOutcomePanel(
              outcome: QuestionOutcome.fromJson(questionFixture(), 'patient-a'),
              onRetry: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(QuestionSource), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    },
  );
}
