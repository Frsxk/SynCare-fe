import 'package:syncare_flutter/models/checkin_record.dart';

Map<String, dynamic> checkinJson({
  String id = 'report-a',
  String patientId = 'patient-a',
  String state = 'SUCCEEDED',
  bool urgent = false,
}) => {
  'id': id,
  'patientId': patientId,
  'message': 'Data sintetis khusus unit test.',
  'submittedBy': 'account-a',
  'createdAt': '2026-10-25T00:00:00Z',
  'version': 1,
  'baseline': {
    'assessmentId': 'assessment-a',
    'confirmationId': 'confirmation-a',
    'score': 1,
    'dischargeId': 'source-a',
    'sourceVersion': 1,
    'applicable': true,
  },
  'processing': {
    'id': 'attempt-$id',
    'state': state,
    'version': state == 'PENDING' || state == 'BLOCKED_BASELINE'
        ? 1
        : state == 'RUNNING'
        ? 2
        : 3,
    'updatedAt': '2026-10-25T00:00:00Z',
    'failureCode': null,
  },
  'outcome': state != 'SUCCEEDED'
      ? null
      : urgent
      ? {
          'action': 'escalate_immediately',
          'reason': 'Kutipan mendesak dari F2 sintetis',
        }
      : {
          'action': 'continue_monitoring',
          'patient_id': patientId,
          'baseline_score': 1,
          'baseline_tier': 'LOW',
          'score': 1,
          'tier': 'LOW',
          'tier_changed': false,
          'next_checkin_days': 7,
          'label': 'demo-heuristic-v1',
          'disclaimer': 'Data sintetis unit test; bukan keputusan klinis.',
          'adjustments': <Object?>[],
          'extraction': {
            'symptoms': <String>[],
            'medication_adherence': 'regular',
            'red_flag': false,
            'quote_of_red_flag': '',
          },
        },
  'alertEvidence': urgent ? 'queued' : 'not_applicable',
};
CheckinRecord checkinFixture({
  String id = 'report-a',
  String patientId = 'patient-a',
  String state = 'SUCCEEDED',
  bool urgent = false,
}) => CheckinRecord.fromJson(
  checkinJson(id: id, patientId: patientId, state: state, urgent: urgent),
);
const guidanceFixture = EmergencyGuidance(
  content: 'Panduan sintetis unit test. Jangan menunggu aplikasi.',
  region: 'Indonesia',
  source: 'https://synthetic.invalid/guidance',
  verifiedAt: '2026-10-25T00:00:00Z',
  version: 1,
  contacts: [(label: 'Informasi saja', number: '119')],
);
