import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncare_flutter/core/providers.dart';
import 'package:syncare_flutter/core/session_api.dart';
import 'package:syncare_flutter/features/auth/session_controller.dart';
import 'package:syncare_flutter/models/discharge_result.dart';
import 'package:syncare_flutter/models/session.dart';

import '../features/auth/session_controller_test.dart'
    show FakeSessionApi, grant;
import '../helpers/fakes.dart';

class DelayedAdapter implements HttpClientAdapter {
  final pending = Completer<ResponseBody>();
  final started = Completer<void>();
  final sent = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? stream,
    Future<void>? cancelFuture,
  ) {
    sent.add(options);
    if (!started.isCompleted) started.complete();
    return pending.future;
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'late API response and in-flight input from A cannot enter the B provider generation',
    () async {
      final adapters = <DelayedAdapter>[];
      final api = FakeSessionApi()..onLogin = (id, _) async => grant(id);
      final scope = ProviderContainer(
        overrides: [
          sessionApiProvider.overrideWithValue(api),
          tokenSourceProvider.overrideWithValue(FakeTokenSource()),
          sessionDioFactoryProvider.overrideWithValue(() {
            final adapter = DelayedAdapter();
            adapters.add(adapter);
            return Dio()..httpClientAdapter = adapter;
          }),
        ],
      );
      addTearDown(scope.dispose);
      scope.read(sessionControllerProvider);
      await Future<void>.delayed(Duration.zero);
      final session = scope.read(sessionControllerProvider.notifier);
      await session.login('a', 'synthetic-password');
      final old = scope.read(apiProvider);
      final pending = old.health();
      final denied = expectLater(pending, throwsException);
      await adapters.single.started.future;
      expect(
        adapters.single.sent.single.headers['Authorization'],
        'Bearer synthetic-session-a',
      );
      scope.read(f1ResultProvider.notifier).state = const DischargeResult();
      await session.login('b', 'synthetic-password');
      scope.read(apiProvider);
      expect(scope.read(f1ResultProvider), isNull);
      adapters.first.pending.complete(
        ResponseBody.fromString(
          '{"status":"account-A"}',
          200,
          headers: {
            'content-type': ['application/json'],
          },
        ),
      );
      await denied;
      expect(
        (scope.read(sessionControllerProvider) as SessionAuthenticated)
            .session
            .principal
            .id,
        'b',
      );
      final current = scope.read(apiProvider).health();
      await adapters.last.started.future;
      expect(
        adapters.last.sent.single.headers['Authorization'],
        'Bearer synthetic-session-b',
      );
      adapters.last.pending.complete(
        ResponseBody.fromString(
          '{"status":"account-B"}',
          200,
          headers: {
            'content-type': ['application/json'],
          },
        ),
      );
      expect((await current).status, 'account-B');
      await expectLater(
        old.checkin(patientId: 'record-a', message: 'Pending A input'),
        throwsException,
      );
      expect(adapters.last.sent, hasLength(1));
    },
  );
}
