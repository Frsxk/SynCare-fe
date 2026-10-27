import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncare_flutter/core/api_exception.dart';
import 'package:syncare_flutter/features/patient/checkin_providers.dart';
import 'package:syncare_flutter/models/checkin_record.dart';
import '../../helpers/fakes.dart';
import '../../helpers/checkin_fixture.dart';

void main() {
  test(
    'starting a new report discards a late status response for the preceding receipt',
    () async {
      final response = Completer<CheckinRecord>();
      final api = FakeSyncareApi()
        ..onSubmitCheckin = (id, message, key) async => checkinFixture();
      api.onGetCheckin = (_) => response.future;
      final controller = CheckinSubmitController(api, 'patient-a');
      addTearDown(controller.dispose);
      await controller.submit('original');
      final refresh = controller.refresh();
      controller.startNew();
      response.complete(checkinFixture());
      await refresh;
      expect(controller.state, isA<CheckinDraft>());
    },
  );
  test(
    'same intent survives lost receipt, edits and reconciliation; explicit new report uses a new UUID',
    () async {
      final keys = <String>[], messages = <String>[];
      final api = FakeSyncareApi()
        ..onSubmitCheckin = (id, message, key) async {
          keys.add(key);
          messages.add(message);
          if (keys.length == 1) throw const NetworkException();
          return checkinFixture(patientId: id);
        };
      final controller = CheckinSubmitController(api, 'patient-a');
      addTearDown(controller.dispose);
      await controller.submit('original');
      expect(controller.state, isA<CheckinSendFailure>());
      await controller.submit('changed while outcome unknown');
      expect(controller.state, isA<CheckinSaved>());
      expect(keys[1], keys[0]);
      expect(messages, ['original', 'original']);
      controller.startNew();
      await controller.submit('original');
      expect(keys[2], isNot(keys[0]));
    },
  );
  test(
    'doubletap sends one report and late disposed response cannot resurrect it',
    () async {
      final pending = Completer<CheckinRecord>();
      var calls = 0;
      final api = FakeSyncareApi()
        ..onSubmitCheckin = (id, message, key) {
          calls++;
          return pending.future;
        };
      final controller = CheckinSubmitController(api, 'patient-a');
      final first = controller.submit('message');
      await controller.submit('message');
      expect(calls, 1);
      controller.dispose();
      pending.complete(checkinFixture());
      await first;
    },
  );
  test(
    'saved-not-analyzed remains saved on offline refresh; revoked access clears cached report',
    () async {
      final api = FakeSyncareApi()
        ..onSubmitCheckin = (id, message, key) async =>
            checkinFixture(state: 'PENDING');
      api.onGetCheckin = (_) => throw const NetworkException();
      final controller = CheckinSubmitController(api, 'patient-a');
      addTearDown(controller.dispose);
      await controller.submit('message');
      await controller.refresh();
      expect(
        (controller.state as CheckinSaved).record.processing,
        ProcessingState.pending,
      );
      expect((controller.state as CheckinSaved).error, isA<NetworkException>());
      api.onGetCheckin = (_) => throw const ForbiddenException();
      await controller.refresh();
      expect(controller.state, isA<CheckinUnavailable>());
    },
  );
  test(
    'history pagination, empty and failed refresh are separate; permission loss removes prior records',
    () async {
      var second = false;
      final api = FakeSyncareApi()
        ..onListCheckins = (id, cursor) async => cursor == null
            ? CheckinPage([checkinFixture()], 'next')
            : CheckinPage([checkinFixture(id: 'report-b')], null);
      final controller = CheckinHistoryController(api, 'patient-a');
      addTearDown(controller.dispose);
      await controller.load();
      await controller.load(next: true);
      expect(controller.state.requireValue.records.length, 2);
      api.onListCheckins = (id, cursor) async {
        if (!second) throw const NetworkException();
        throw const ForbiddenException();
      };
      await controller.load();
      expect(controller.state.valueOrNull?.records.length, 2);
      second = true;
      await controller.load();
      expect(controller.state.valueOrNull, isNull);
    },
  );
}
