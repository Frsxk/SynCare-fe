import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncare_flutter/core/api_exception.dart';
import 'package:syncare_flutter/core/config.dart';
import 'package:syncare_flutter/core/providers.dart';
import 'package:syncare_flutter/features/patient/ask_screen.dart';
import 'package:syncare_flutter/models/ask_answer.dart';
import 'package:syncare_flutter/widgets/disclaimer_banner.dart';
import 'package:syncare_flutter/widgets/empty_state.dart';
import 'package:syncare_flutter/widgets/error_state.dart';
import 'package:syncare_flutter/widgets/source_chip.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> pumpAskScreen(WidgetTester tester, FakeSyncareApi api) async {
    await tester.pumpWidget(
      wrapScreen(
        const PatientAskScreen(),
        overrides: <Override>[apiProvider.overrideWithValue(api)],
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> submitQuestion(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.pump();
    await tester.tap(find.text('Tanya'));
    await tester.pump();
  }

  testWidgets(
    'renders the disclaimer first, the patient caption, the empty state, and the form',
    (tester) async {
      final FakeSyncareApi api = FakeSyncareApi();

      await pumpAskScreen(tester, api);

      expect(find.byType(DisclaimerBanner), findsOneWidget);
      expect(
        find.text('ID pasien: ${AppConfig.defaultPatientId}'),
        findsOneWidget,
      );

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('Belum ada pertanyaan'), findsOneWidget);
      expect(
        find.text(
          'Tanyakan hal yang berkaitan dengan rencana tindak lanjut Anda.',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.question_answer_outlined), findsOneWidget);

      final TextField field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text ?? '', isEmpty);
      expect(field.maxLines, greaterThan(1));
      expect(find.text('Tanya'), findsOneWidget);
      expect(find.byType(ErrorState), findsNothing);

      final double bannerTop = tester
          .getTopLeft(find.byType(DisclaimerBanner))
          .dy;
      final double emptyTop = tester.getTopLeft(find.byType(EmptyState)).dy;
      expect(bannerTop, lessThan(emptyTop));
    },
  );

  testWidgets('rejects a blank question without calling the API', (
    tester,
  ) async {
    final FakeSyncareApi api = FakeSyncareApi();
    int calls = 0;
    api.onAsk = ({required String patientId, required String query}) async {
      calls++;
      return const AskAnswer(
        text: 'tidak seharusnya',
        rawText: 'tidak seharusnya',
      );
    };

    await pumpAskScreen(tester, api);
    await submitQuestion(tester, '   ');

    expect(calls, 0);
    expect(find.text('Tulis pertanyaan terlebih dahulu.'), findsOneWidget);
    expect(find.byType(EmptyState), findsOneWidget);
  });

  testWidgets('shows a spinner while the answer is pending', (tester) async {
    final FakeSyncareApi api = FakeSyncareApi();
    final Completer<AskAnswer> completer = Completer<AskAnswer>();
    String? sentPatientId;
    String? sentQuery;
    api.onAsk = ({required String patientId, required String query}) {
      sentPatientId = patientId;
      sentQuery = query;
      return completer.future;
    };

    await pumpAskScreen(tester, api);
    await submitQuestion(tester, 'bolehkah saya berolahraga?');

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(EmptyState), findsNothing);
    expect(sentPatientId, AppConfig.defaultPatientId);
    expect(sentQuery, 'bolehkah saya berolahraga?');

    final FilledButton button = tester.widget<FilledButton>(
      find.byType(FilledButton),
    );
    expect(button.onPressed, isNull);

    completer.complete(
      const AskAnswer(
        text: 'Anda boleh berjalan kaki 20 menit setiap pagi.',
        rawText: 'Anda boleh berjalan kaki 20 menit setiap pagi.',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      find.text('Anda boleh berjalan kaki 20 menit setiap pagi.'),
      findsOneWidget,
    );
  });

  testWidgets('renders a grounded answer verbatim with its source chip', (
    tester,
  ) async {
    const String rawText =
        'Istirahatkan kaki Anda dan hubungi klinik bila sesak memberat.\n\n'
        '[patient:care_intensity:1#1 | f5_grounded_answer]';
    final FakeSyncareApi api = FakeSyncareApi();
    api.onAsk = ({required String patientId, required String query}) async =>
        AskAnswer.fromText(rawText);

    await pumpAskScreen(tester, api);
    await submitQuestion(tester, 'apa yang harus saya lakukan?');
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Istirahatkan kaki Anda dan hubungi klinik bila sesak memberat.',
      ),
      findsOneWidget,
    );
    expect(find.byType(SourceChip), findsOneWidget);
    expect(
      find.text('Sumber: patient:care_intensity:1#1 | f5_grounded_answer'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Jawaban berasal dari rencana yang disetujui. Bukan nasihat medis.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Teks verbatim'));
    await tester.pumpAndSettle();

    expect(find.text(rawText), findsOneWidget);
  });

  testWidgets('renders a plain refusal unchanged and without a source chip', (
    tester,
  ) async {
    const String refusal =
        'Saya belum bisa menjawab karena belum ada rencana tindak lanjut '
        'yang disetujui.';
    final FakeSyncareApi api = FakeSyncareApi();
    api.onAsk = ({required String patientId, required String query}) async =>
        AskAnswer.fromText(refusal);

    await pumpAskScreen(tester, api);
    await submitQuestion(tester, 'bolehkah saya berolahraga?');
    await tester.pumpAndSettle();

    expect(find.text(refusal), findsOneWidget);
    expect(find.byType(SourceChip), findsNothing);
    expect(find.textContaining('Sumber:'), findsNothing);
  });

  testWidgets(
    'maps StreamUnavailableException to the retry copy and retries the last query',
    (tester) async {
      final FakeSyncareApi api = FakeSyncareApi();
      final List<String> queries = <String>[];
      api.onAsk = ({required String patientId, required String query}) async {
        queries.add(query);
        if (queries.length == 1) {
          throw const StreamUnavailableException();
        }
        return const AskAnswer(
          text: 'Jawaban dari percobaan kedua.',
          rawText: 'Jawaban dari percobaan kedua.',
        );
      };

      await pumpAskScreen(tester, api);
      await submitQuestion(tester, 'bolehkah saya berolahraga?');
      await tester.pumpAndSettle();

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.text('Tidak bisa membuka aliran peristiwa'), findsOneWidget);
      expect(find.text('Coba lagi'), findsOneWidget);
      expect(find.textContaining('StreamUnavailableException'), findsNothing);

      await tester.ensureVisible(find.text('Coba lagi'));
      await tester.pump();
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();

      expect(queries, <String>[
        'bolehkah saya berolahraga?',
        'bolehkah saya berolahraga?',
      ]);
      expect(find.byType(ErrorState), findsNothing);
      expect(find.text('Jawaban dari percobaan kedua.'), findsOneWidget);
    },
  );
}
