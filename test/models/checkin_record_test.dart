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
  test('createdLabel is WIB while createdAt stays the raw UTC value', () {
    final record = checkinFixture();
    expect(record.createdAt, '2026-10-25T00:00:00Z');
    expect(record.createdLabel, '2026-10-25 07:00 WIB');

    final late = CheckinRecord.fromJson(<String, dynamic>{
      ...checkinJson(),
      'createdAt': '2026-10-25T18:30:00Z',
    });
    expect(late.createdAt, '2026-10-25T18:30:00Z');
    expect(late.createdLabel, '2026-10-26 01:30 WIB');

    final equivalentOffset = CheckinRecord.fromJson(<String, dynamic>{
      ...checkinJson(),
      'createdAt': '2026-10-25T07:00:00+07:00',
    });
    expect(equivalentOffset.createdAt, '2026-10-25T07:00:00+07:00');
    expect(equivalentOffset.createdLabel, '2026-10-25 07:00 WIB');
  });
  test('missing or invalid createdAt fails validation instead of 1970 or now', () {
    final missing = checkinJson()..remove('createdAt');
    for (final Map<String, dynamic> json in <Map<String, dynamic>>[
      missing,
      <String, dynamic>{...checkinJson(), 'createdAt': ''},
      <String, dynamic>{...checkinJson(), 'createdAt': 'not-a-date'},
      <String, dynamic>{...checkinJson(), 'createdAt': '2026-10-25'},
      <String, dynamic>{...checkinJson(), 'createdAt': '2026-13-01T00:00:00Z'},
    ]) {
      expect(
        () => CheckinRecord.fromJson(json),
        throwsA(isA<InvalidResponseException>()),
      );
    }
  });
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
