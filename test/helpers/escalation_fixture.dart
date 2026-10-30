import 'package:syncare_flutter/models/escalation.dart';

Map<String, dynamic> escalationJson({
  String id = 'alert-a',
  String patientId = 'patient-a',
  String status = 'PENDING_REVIEW',
}) {
  const statuses = [
    'PENDING_REVIEW',
    'ACKNOWLEDGED',
    'IN_PROGRESS',
    'RESOLVED',
  ];
  final version = statuses.indexOf(status) + 1;
  return {
    'id': id,
    'patientId': patientId,
    'source': {
      'type': 'F2',
      'reportId': 'report-a',
      'attemptId': 'attempt-a',
      'action': 'escalate_immediately',
      'reason': 'Alasan akut sintetis asli F2.',
      'reportedAt': '2026-10-25T12:00:00.000Z',
      'outcomeAt': '2026-10-25T12:00:01.000Z',
    },
    'urgency': 'acute',
    'status': status,
    'version': version,
    'acknowledgedAt': version > 1 ? '2026-10-25T12:00:03.000Z' : null,
    'resolvedAt': status == 'RESOLVED' ? '2026-10-25T12:00:05.000Z' : null,
    'createdAt': '2026-10-25T12:00:02.000Z',
    'updatedAt': '2026-10-25T12:00:05.000Z',
    'timeline': [
      for (var i = 0; i < version; i++)
        {
          'id': '$id-event-$i',
          'version': i + 1,
          'status': statuses[i],
          'recordedAt': '2026-10-25T12:00:0${i + 2}.000Z',
          'patientSummary': i > 1 ? 'Ringkasan publik sintetis $i.' : null,
        },
    ],
    'timelineNextCursor': null,
  };
}

Escalation escalationFixture({
  String id = 'alert-a',
  String patientId = 'patient-a',
  String status = 'PENDING_REVIEW',
}) => Escalation.fromJson(
  escalationJson(id: id, patientId: patientId, status: status),
  detail: true,
);

/// New direct patient emergency request (contract: PATIENT_REQUEST source).
///
/// Deliberately has no reportId/attemptId: those belong to F2 check-in alerts
/// and must never be fabricated for a patient-authored request.
Map<String, dynamic> patientRequestJson({
  String id = 'alert-request-a',
  String patientId = 'patient-a',
  String requestId = 'request-a',
  String status = 'PENDING_REVIEW',
  String reason = 'Pasien meminta bantuan segera.',
}) {
  const statuses = [
    'PENDING_REVIEW',
    'ACKNOWLEDGED',
    'IN_PROGRESS',
    'RESOLVED',
  ];
  final version = statuses.indexOf(status) + 1;
  if (version < 1) {
    throw ArgumentError.value(status, 'status', 'unknown escalation status');
  }
  return {
    'id': id,
    'patientId': patientId,
    'source': {
      'type': 'PATIENT_REQUEST',
      'requestId': requestId,
      'action': 'request_immediate_help',
      'reason': reason,
      'reportedAt': '2026-10-30T09:00:00.000Z',
      'outcomeAt': '2026-10-30T09:00:00.000Z',
    },
    'urgency': 'acute',
    'status': status,
    'version': version,
    'acknowledgedAt': version > 1 ? '2026-10-30T09:00:03.000Z' : null,
    'resolvedAt': status == 'RESOLVED' ? '2026-10-30T09:00:05.000Z' : null,
    'createdAt': '2026-10-30T09:00:01.000Z',
    'updatedAt': '2026-10-30T09:00:05.000Z',
    'timeline': [
      for (var i = 0; i < version; i++)
        {
          'id': '$id-event-$i',
          'version': i + 1,
          'status': statuses[i],
          'recordedAt': '2026-10-30T09:00:0${i + 2}.000Z',
          'patientSummary': i > 1 ? 'Ringkasan publik sintetis $i.' : null,
        },
    ],
    'timelineNextCursor': null,
  };
}

Escalation patientRequestFixture({
  String id = 'alert-request-a',
  String patientId = 'patient-a',
  String requestId = 'request-a',
  String status = 'PENDING_REVIEW',
  String reason = 'Pasien meminta bantuan segera.',
}) => Escalation.fromJson(
  patientRequestJson(
    id: id,
    patientId: patientId,
    requestId: requestId,
    status: status,
    reason: reason,
  ),
  detail: true,
);
