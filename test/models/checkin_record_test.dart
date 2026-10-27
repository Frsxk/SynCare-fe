import 'package:flutter_test/flutter_test.dart';
import 'package:syncare_flutter/core/api_exception.dart';
import 'package:syncare_flutter/models/checkin_record.dart';
import '../helpers/checkin_fixture.dart';

void main() {
  test(
    'strict persisted record distinguishes pending, unknown and actual routine/urgent without inventing scores',
    () {
      expect(checkinFixture(state: 'PENDING').outcome, isNull);
      expect(
        checkinFixture(state: 'UNKNOWN').processing,
        ProcessingState.unknown,
      );
      expect(checkinFixture().outcome, isA<RoutineCheckinOutcome>());
      expect(checkinFixture(urgent: true).outcome, isA<UrgentCheckinOutcome>());
      for (final field in [
        'score',
        'tier',
        'disclaimer',
        'next_checkin_days',
      ]) {
        final json = checkinJson();
        (json['outcome'] as Map).remove(field);
        expect(
          () => CheckinRecord.fromJson(json),
          throwsA(isA<InvalidResponseException>()),
        );
      }
    },
  );
  test(
    'foreign output/baseline, fabricated date and nonterminal success rejected',
    () {
      final json = checkinJson();
      (json['outcome'] as Map)['patient_id'] = 'foreign';
      expect(
        () => CheckinRecord.fromJson(json),
        throwsA(isA<InvalidResponseException>()),
      );
      expect(
        () =>
            CheckinRecord.fromJson({...checkinJson(), 'createdAt': 'invalid'}),
        throwsA(isA<InvalidResponseException>()),
      );
      expect(
        () => CheckinRecord.fromJson({
          ...checkinJson(state: 'PENDING'),
          'outcome': checkinJson()['outcome'],
        }),
        throwsA(isA<InvalidResponseException>()),
      );
    },
  );
}
