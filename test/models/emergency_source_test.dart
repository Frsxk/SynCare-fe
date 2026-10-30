import 'package:flutter_test/flutter_test.dart';
import 'package:syncare_flutter/core/api_exception.dart';
import 'package:syncare_flutter/models/escalation.dart';
import '../helpers/escalation_fixture.dart';

Map<String, dynamic> _withSource(
  Map<String, dynamic> base,
  Map<String, Object?> patch,
) => {
  ...base,
  'source': {
    ...(base['source'] as Map<String, dynamic>),
    ...patch,
  },
};

void main() {
  test(
    'legacy F2 source keeps report/attempt evidence and is not a patient request',
    () {
      final alert = escalationFixture();
      expect(alert.sourceType, 'F2');
      expect(alert.reportId, 'report-a');
      expect(alert.attemptId, 'attempt-a');
      expect(alert.requestId, isNull);
      expect(alert.isPatientRequest, isFalse);
    },
  );

  test(
    'PATIENT_REQUEST source uses requestId only and never fabricates report or attempt ids',
    () {
      final alert = patientRequestFixture();
      expect(alert.sourceType, 'PATIENT_REQUEST');
      expect(alert.requestId, 'request-a');
      expect(alert.reportId, isNull);
      expect(alert.attemptId, isNull);
      expect(alert.isPatientRequest, isTrue);
      expect(alert.reason, 'Pasien meminta bantuan segera.');
      expect(alert.outcomeAt, '2026-10-30T09:00:00.000Z');
      expect(alert.outcomeLabel, isNotNull);
    },
  );

  test(
    'PATIENT_REQUEST outcomeAt is nullish while F2 still requires a real instant',
    () {
      final absent = patientRequestJson();
      (absent['source'] as Map<String, dynamic>).remove('outcomeAt');
      final absentAlert = Escalation.fromJson(absent, detail: true);
      expect(absentAlert.outcomeAt, isNull);
      final nullAlert = Escalation.fromJson(
        _withSource(patientRequestJson(), {'outcomeAt': null}),
        detail: true,
      );
      expect(nullAlert.outcomeAt, isNull);
      expect(
        () => Escalation.fromJson(
          _withSource(patientRequestJson(), {
            'outcomeAt': '2026-10-30T09:00:00Z',
          }),
          detail: true,
        ),
        throwsA(isA<InvalidResponseException>()),
      );
      expect(
        () => Escalation.fromJson(
          _withSource(escalationJson(), {'outcomeAt': null}),
          detail: true,
        ),
        throwsA(isA<InvalidResponseException>()),
      );
    },
  );

  test(
    'source union rejects mixed schemas, unknown types, wrong actions and fabricated links',
    () {
      for (final patch in <Map<String, Object?>>[
        {'type': 'MANUAL'},
        {'action': 'escalate_immediately'},
        {'reportId': 'report-injected'},
        {'attemptId': 'attempt-injected'},
        {'type': 'PATIENT_REQUEST', 'reportId': 'report-injected'},
        {'type': 'PATIENT_REQUEST', 'attemptId': 'attempt-injected'},
      ]) {
        expect(
          () => Escalation.fromJson(
            _withSource(patientRequestJson(), patch),
            detail: true,
          ),
          throwsA(isA<InvalidResponseException>()),
          reason: 'patient request patch $patch',
        );
      }
      for (final patch in <Map<String, Object?>>[
        {'requestId': 'request-injected'},
        {'type': 'PATIENT_REQUEST'},
        {'action': 'request_immediate_help'},
      ]) {
        expect(
          () => Escalation.fromJson(
            _withSource(escalationJson(), patch),
            detail: true,
          ),
          throwsA(isA<InvalidResponseException>()),
          reason: 'F2 patch $patch',
        );
      }
      for (final patch in <Map<String, Object?>>[
        {'urgency': 'high'},
        {'urgency': 'guessed-high-risk'},
      ]) {
        expect(
          () => Escalation.fromJson({
            ...patientRequestJson(),
            ...patch,
          }, detail: true),
          throwsA(isA<InvalidResponseException>()),
          reason: 'request urgency patch $patch',
        );
      }
    },
  );

  test('history overlay preserves patient request provenance', () {
    final alert = patientRequestFixture().withHistory(
      patientRequestFixture().timeline,
      'older',
    );
    expect(alert.sourceType, 'PATIENT_REQUEST');
    expect(alert.requestId, 'request-a');
    expect(alert.reportId, isNull);
    expect(alert.attemptId, isNull);
    expect(alert.isPatientRequest, isTrue);
    expect(alert.timelineNextCursor, 'older');
  });

  test(
    '201 envelope parses resource/replayed and rejects foreign, F2 or malformed resources',
    () {
      final parsed = EmergencyRequestResult.fromJson({
        'resource': patientRequestJson(),
        'replayed': false,
      }, patientId: 'patient-a');
      expect(parsed.alert.id, 'alert-request-a');
      expect(parsed.alert.isPatientRequest, isTrue);
      expect(parsed.replayed, isFalse);

      final replay = EmergencyRequestResult.fromJson({
        'resource': patientRequestJson(),
        'replayed': true,
      }, patientId: 'patient-a');
      expect(replay.replayed, isTrue);

      for (final value in <Object?>[
        {
          'resource': patientRequestJson(patientId: 'foreign'),
          'replayed': false,
        },
        {'resource': escalationJson(), 'replayed': false},
        {'resource': patientRequestJson(), 'replayed': 'false'},
        {'resource': patientRequestJson()},
        {'replayed': false},
      ]) {
        expect(
          () => EmergencyRequestResult.fromJson(value, patientId: 'patient-a'),
          throwsA(isA<InvalidResponseException>()),
          reason: 'envelope $value',
        );
      }
    },
  );
}
