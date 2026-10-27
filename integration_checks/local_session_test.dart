import '../tool/private_fixture.dart';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncare_flutter/core/session_api.dart';
import 'package:syncare_flutter/features/auth/session_controller.dart';
import 'package:syncare_flutter/models/session.dart';

import '../test/helpers/fakes.dart';

void main() {
  test(
    'actual Flutter Dio/session controller logs in two local accounts, enforces self scope and revokes logout',
    () async {
      final input = readPrivateFixture(
        File('../SynCare-be/data/local-demo-accounts.json'),
      );
      final accounts = input['patients'] as List<dynamic>;
      final dio = Dio(
        BaseOptions(
          baseUrl: 'http://127.0.0.1:8080',
          contentType: Headers.jsonContentType,
          followRedirects: false,
        ),
      );
      final api = DioSessionApi(dio);
      final scope = ProviderContainer(
        overrides: [
          sessionApiProvider.overrideWithValue(api),
          tokenSourceProvider.overrideWithValue(FakeTokenSource()),
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
      final oldToken = controller.tokenFor(first.generation)!;
      final oldSource = GenerationTokenSource(controller, first.generation);
      await controller.logout();
      var revoked = false;
      try {
        await api.restore(oldToken);
      } on SessionException catch (error) {
        revoked = error.failure == SessionFailure.invalidCredentials;
      }
      expect(revoked, isTrue);
      await controller.login(
        accounts[1]['identifier'] as String,
        accounts[1]['password'] as String,
      );
      final second =
          scope.read(sessionControllerProvider) as SessionAuthenticated;
      expect(first.session.principal.id != second.session.principal.id, isTrue);
      expect(
        first.session.principal.patientId != second.session.principal.patientId,
        isTrue,
      );
      expect(await oldSource.read(), isNull);
      final token = controller.tokenFor(second.generation)!;
      var status = 0;
      try {
        await dio.get<Object?>(
          '/api/v1/patients/${first.session.principal.patientId}',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
      } on DioException catch (error) {
        status = error.response?.statusCode ?? 0;
      }
      expect(status, 404);
      final response = await dio.get<Object?>(
        '/api/v1/patients/${second.session.principal.patientId}',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      expect(response.statusCode, 200);
      await controller.logout();
      expect(scope.read(sessionControllerProvider), isA<SessionSignedOut>());
    },
  );
}
