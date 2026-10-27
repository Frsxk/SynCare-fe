import 'package:syncare_flutter/models/homecare.dart';
import 'homecare_fixture.dart';

Map<String, dynamic> lifecycleJson({
  String id = 'booking-a',
  String status = 'Requested',
  String patientId = 'patient-a',
  bool cancelledAfterSchedule = false,
}) {
  final data = bookingJson(status: status, patientId: patientId);
  data['id'] = id;
  final scheduled =
      status == 'Scheduled' || status == 'Completed' || cancelledAfterSchedule;
  if (scheduled) {
    data['assignedStaff'] = <String, dynamic>{
      'id': 'nurse-a',
      'displayName': 'Perawat sintetis A',
    };
    data['confirmedSlot'] = <String, dynamic>{
      'startAt': '2030-01-02T02:00:00.000Z',
      'endAt': '2030-01-02T03:00:00.000Z',
      'timezone': 'Asia/Jakarta',
    };
  }
  if (status == 'Completed') {
    data['completedAt'] = '2030-01-02T03:05:00.000Z';
    data['completionNote'] = 'Catatan kunjungan sintetis untuk pasien.';
  }
  final states = [
    'Requested',
    if (status != 'Requested') 'Under Review',
    if (scheduled) 'Scheduled',
    if (['Completed', 'Cancelled', 'Rejected'].contains(status)) status,
  ];
  data['version'] = states.length;
  data['timeline'] = <Map<String, dynamic>>[
    for (var i = 0; i < states.length; i++)
      <String, dynamic>{
        'id': '$id-event-$i',
        'version': i + 1,
        'fromStatus': i == 0 ? null : states[i - 1],
        'toStatus': states[i],
        'actorId': i == 0 ? 'patient-session' : 'nurse-a',
        'occurredAt': '2026-10-25T12:00:00.000Z',
        'reason': ['Cancelled', 'Rejected'].contains(states[i])
            ? 'Alasan sintetis yang dibaca pasien.'
            : null,
      },
  ];
  return data;
}

Booking lifecycleFixture({
  String id = 'booking-a',
  String status = 'Requested',
  String patientId = 'patient-a',
  bool cancelledAfterSchedule = false,
}) => Booking.fromJson(
  lifecycleJson(
    id: id,
    status: status,
    patientId: patientId,
    cancelledAfterSchedule: cancelledAfterSchedule,
  ),
);
