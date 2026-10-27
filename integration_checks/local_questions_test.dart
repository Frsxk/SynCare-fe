import '../tool/private_fixture.dart';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncare_flutter/core/providers.dart';
import 'package:syncare_flutter/core/session_api.dart';
import 'package:syncare_flutter/core/api_exception.dart';
import 'package:syncare_flutter/features/auth/session_controller.dart';
import 'package:syncare_flutter/features/patient/question_providers.dart';
import 'package:syncare_flutter/features/patient/qa_outcome_panel.dart';
import 'package:syncare_flutter/models/ask_answer.dart';
import 'package:syncare_flutter/models/session.dart';
import '../test/helpers/fakes.dart';
import '../test/helpers/pump_app.dart';

void main() {
  test(
    'actual Q1 API/provider uses own identity, logout clears answer, other patient cannot read first context',
    () async {
      final previous = HttpOverrides.current;
      HttpOverrides.global = null;
      addTearDown(() => HttpOverrides.global = previous);
      final accounts =
              (readPrivateFixture(
                        File('../SynCare-be/data/local-demo-accounts.json'),
                      )
                      as Map)['patients']
                  as List,
          dio = Dio(
            BaseOptions(
              baseUrl: 'http://127.0.0.1:8080',
              contentType: Headers.jsonContentType,
              followRedirects: false,
            ),
          ),
          scope = ProviderContainer(
            overrides: [
              sessionApiProvider.overrideWithValue(DioSessionApi(dio)),
              tokenSourceProvider.overrideWithValue(FakeTokenSource()),
              apiBaseUrlProvider.overrideWithValue('http://127.0.0.1:8080'),
            ],
          );
      addTearDown(() => {scope.dispose(), dio.close(force: true)});
      scope.read(sessionControllerProvider);
      await Future<void>.delayed(Duration.zero);
      final session = scope.read(sessionControllerProvider.notifier),
          listener = scope.listen(questionProvider, (_, _) {});
      addTearDown(listener.close);
      try {
        await session.login(
          accounts[0]['identifier'] as String,
          accounts[0]['password'] as String,
        );
        final first =
            (scope.read(sessionControllerProvider) as SessionAuthenticated)
                .session
                .principal
                .patientId!;
        await scope
            .read(questionProvider.notifier)
            .submit('Apa aktivitas tindak lanjut rutin pada rencana saya?');
        final outcome = scope.read(questionProvider).requireValue;
        expect(outcome is AskAnswer || outcome is QuestionRefusal, true);
        if (outcome is AskAnswer) {
          expect(outcome.citations, isNotEmpty);
          expect(
            outcome.citations.every(
              (c) => !c.approved || c.id.startsWith('$first:'),
            ),
            true,
          );
        }
        await session.logout();
        expect(scope.read(questionProvider).valueOrNull, isNull);
        await session.login(
          accounts[1]['identifier'] as String,
          accounts[1]['password'] as String,
        );
        await expectLater(
          scope
              .read(apiProvider)
              .ask(patientId: first, query: 'foreign context'),
          throwsA(isA<NotFoundException>()),
        );
        await scope
            .read(questionProvider.notifier)
            .submit('Saya mengalami nyeri dada yang berat.');
        final urgent = scope.read(questionProvider).requireValue;
        expect(urgent, isA<QuestionEmergency>());
        expect(
          (urgent as QuestionEmergency).reason,
          'Saya mengalami nyeri dada yang berat.',
        );
        File('../SynCare-be/data/m09-flutter-evidence.json').writeAsStringSync(
          jsonEncode({
            'verifiedAt': DateTime.now().toUtc().toIso8601String(),
            'actualHttp': true,
            'firstKind': outcome is AskAnswer ? 'answer' : 'refusal',
            'urgentKind': 'emergency',
            'foreignDenied': true,
            'logoutClears': true,
            'nativePluginVerified': false,
          }),
        );
      } finally {
        await session.logout();
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
  testWidgets(
    'captured actual three-source Q1 response renders all provenance at320/text200',
    (tester) async {
      final evidence =
              jsonDecode(
                    File(
                      '../SynCare-be/data/m09-api-private.json',
                    ).readAsStringSync(),
                  )
                  as Map,
          record =
              (evidence['cases'] as List).firstWhere(
                    (v) => v['name'] == 'approved',
                  )
                  as Map,
          outcome = QuestionOutcome.fromJson(
            record['body']['data'],
            record['patientId'] as String,
          );
      expect((outcome as AskAnswer).citations.length, 3);
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        wrapScreen(
          SingleChildScrollView(
            child: QaOutcomePanel(outcome: outcome, onRetry: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(QuestionSource), findsNWidgets(3));
      expect(find.text(outcome.text), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
