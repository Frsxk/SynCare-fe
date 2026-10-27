import '../tool/private_fixture.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:syncare_flutter/core/api_exception.dart';
import 'package:syncare_flutter/core/providers.dart';
import 'package:syncare_flutter/core/session_api.dart';
import 'package:syncare_flutter/core/theme.dart';
import 'package:syncare_flutter/features/patient/home_screen.dart';
import 'package:syncare_flutter/features/patient/profile_screen.dart';
import 'package:syncare_flutter/models/patient.dart';
import 'package:syncare_flutter/features/auth/session_controller.dart';
import 'package:syncare_flutter/features/patient/patient_providers.dart';
import 'package:syncare_flutter/models/session.dart';
import 'package:syncare_flutter/widgets/risk_badge.dart';
import '../test/helpers/fakes.dart';

void main() {
  PatientOverview? capturedFirst, capturedSecond;
  test(
    'actual local Dio/provider sessions retrieve committed overview and deny the other patient',
    () async {
      final previousOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      addTearDown(() => HttpOverrides.global = previousOverrides);
      final seed = readPrivateFixture(
        File('../SynCare-be/data/local-demo-accounts.json'),
      );
      final accounts = seed['patients'] as List<dynamic>;
      final dio = Dio(
        BaseOptions(
          baseUrl: 'http://127.0.0.1:8080',
          contentType: Headers.jsonContentType,
          followRedirects: false,
        ),
      );
      final scope = ProviderContainer(
        overrides: [
          sessionApiProvider.overrideWithValue(DioSessionApi(dio)),
          tokenSourceProvider.overrideWithValue(FakeTokenSource()),
          apiBaseUrlProvider.overrideWithValue('http://127.0.0.1:8080'),
        ],
      );
      addTearDown(() {
        scope.dispose();
        dio.close(force: true);
      });
      scope.read(sessionControllerProvider);
      await Future<void>.delayed(Duration.zero);
      final controller = scope.read(sessionControllerProvider.notifier);
      await controller.login(
        accounts[0]['identifier'] as String,
        accounts[0]['password'] as String,
      );
      final first =
          scope.read(sessionControllerProvider) as SessionAuthenticated;
      capturedFirst = await scope.read(ownOverviewProvider.future);
      expect(capturedFirst!.profile.id, first.session.principal.patientId);
      await controller.logout();
      await controller.login(
        accounts[1]['identifier'] as String,
        accounts[1]['password'] as String,
      );
      final second =
          scope.read(sessionControllerProvider) as SessionAuthenticated;
      capturedSecond = await scope.read(ownOverviewProvider.future);
      expect(capturedSecond!.profile.id, second.session.principal.patientId);
      expect(capturedSecond!.profile.id, isNot(capturedFirst!.profile.id));
      await expectLater(
        scope
            .read(apiProvider)
            .getPatientOverview(first.session.principal.patientId!),
        throwsA(isA<NotFoundException>()),
      );
      await controller.logout();
    },
    timeout: const Timeout(Duration(seconds: 45)),
  );

  testWidgets(
    'committed local snapshots render in overview/profile widgets and replacement removes the old identity',
    (tester) async {
      expect(capturedFirst, isNotNull);
      expect(capturedSecond, isNotNull);
      var snapshot = capturedFirst!;
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const PatientHomeScreen()),
          GoRoute(
            path: '/patient/profile',
            builder: (_, _) => const PatientProfileScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);
      final scope = ProviderContainer(
        overrides: [ownOverviewProvider.overrideWith((ref) async => snapshot)],
      );
      addTearDown(scope.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: scope,
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('ID pasien: ${capturedFirst!.profile.id}'),
        findsOneWidget,
      );
      if (capturedFirst!.confirmedRisk.current case final evidence?) {
        expect(
          tester.widget<RiskBadge>(find.byType(RiskBadge)).tier,
          evidence.category,
        );
      }
      await tester.ensureVisible(find.text('Lihat profil saya'));
      await tester.tap(find.text('Lihat profil saya'));
      await tester.pumpAndSettle();
      expect(find.text('Profil saya'), findsOneWidget);
      expect(find.text(capturedFirst!.profile.displayName), findsOneWidget);
      snapshot = capturedSecond!;
      scope.invalidate(ownOverviewProvider);
      await tester.pumpAndSettle();
      expect(
        find.text('ID pasien: ${capturedFirst!.profile.id}'),
        findsNothing,
      );
      expect(
        find.text('ID pasien: ${capturedSecond!.profile.id}'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
