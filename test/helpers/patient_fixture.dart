import 'package:syncare_flutter/models/patient.dart';

Map<String, dynamic> overviewJson({
  String id = 'record-a',
  String status = 'unconfirmed',
  String category = 'LOW',
}) {
  final evidence = <String, dynamic>{
    'id': 'confirmation-a',
    'assessmentId': 'assessment-a',
    'dischargeId': 'source-a',
    'sourceVersion': 1,
    'category': category,
    'score': 0,
    'confirmedBy': 'nurse-a',
    'confirmedAt': '2026-10-25T07:00:00.000Z',
    'applicable': status == 'confirmed',
    'disclaimer': 'Hasil sintetis khusus pengujian. Belum divalidasi klinis.',
    'label': 'test-fixture',
    'version': 1,
  };
  final unavailable = <String, dynamic>{
    'availability': 'unavailable',
    'reason': 'domain_source_not_connected',
  };
  return {
    'profile': {
      'id': id,
      'profile': {'displayName': 'Pasien sintetis $id'},
      'recordedCondition': 'Kondisi dicatat perawat',
      'version': 3,
      'createdAt': '2026-10-25T07:00:00.000Z',
      'updatedAt': '2026-10-25T07:00:00.000Z',
      'source': {
        'actorId': 'nurse-a',
        'recordedAt': '2026-10-25T07:00:00.000Z',
      },
    },
    'currentDischarge': {
      'id': status == 'needs_reassessment' ? 'source-b' : 'source-a',
      'version': status == 'needs_reassessment' ? 2 : 1,
    },
    'confirmedRisk': {
      'status': status,
      'current': status == 'confirmed' ? evidence : null,
      'previous': status == 'needs_reassessment' ? evidence : null,
    },
    'latestAssessment': {
      'output': {'tier': 'HIGH'},
    },
    'currentPlan': unavailable,
    'latestReport': null,
    'latestAnalysis': null,
    'activeBookingCounts': unavailable,
    'openAlertCounts': unavailable,
  };
}

PatientOverview overviewFixture({
  String id = 'record-a',
  String status = 'unconfirmed',
  String category = 'LOW',
}) => PatientOverview.fromJson(
  overviewJson(id: id, status: status, category: category),
);
