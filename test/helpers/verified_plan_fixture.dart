import 'package:syncare_flutter/models/verified_care_plan.dart';

Map<String, dynamic> verifiedPlanJson({
  String patientId = 'patient-a',
  String id = 'approval-a',
  bool applicable = true,
}) => {
  'id': id,
  'patientId': patientId,
  'reviewId': 'review-a',
  'approvedAt': '2026-10-26T03:00:00.123456+00:00',
  'createdAt': '2026-10-26T03:00:01.000Z',
  'source': {
    'assessmentId': 'assessment-a',
    'dischargeId': 'discharge-a',
    'sourceVersion': 1,
    'applicable': applicable,
  },
  'plan': {
    'patient_id': patientId,
    'plan_text': 'Rencana sintetis yang disetujui melalui gate aktual.',
    'tier': 'HIGH',
    'care_intensity': ['Aktivitas yang berasal dari F3.'],
    'status': 'DRAFT pending human approval',
    'label': 'demo-heuristic-v1',
    'missing_facts': [],
    'disclaimer': 'Demo sintetis, belum divalidasi klinis.',
    'satuseshat': {
      'careplan': {
        'activity': ['Aktivitas yang berasal dari F3.'],
      },
      'servicerequest': {
        'patientInstruction':
            'Tindak lanjut pada 2026-11-02; kontak rutin Kontak demo sintetis.',
        'priority': 'urgent',
      },
      'task': [
        {'code': 'fixture', 'status': 'requested', 'priority': 'urgent'},
      ],
    },
  },
};
VerifiedCarePlan verifiedPlanFixture({
  String patientId = 'patient-a',
  String id = 'approval-a',
  bool applicable = true,
}) => VerifiedCarePlan.fromJson(
  verifiedPlanJson(patientId: patientId, id: id, applicable: applicable),
);
