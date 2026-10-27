import 'package:syncare_flutter/models/homecare.dart';

const demoService = HomecareService(
  id: 'post-discharge-nurse-demo',
  name: 'Kunjungan perawat pascapulang (simulasi)',
  description: 'Simulasi kunjungan DKI Jakarta.',
  version: 1,
  cities: ['Jakarta Pusat'],
);
const bookingInput = BookingInput(
  serviceId: 'post-discharge-nurse-demo',
  fullAddress: 'Alamat sintetis nomor 1',
  kelurahan: 'Kelurahan uji',
  kecamatan: 'Kecamatan uji',
  city: 'Jakarta Pusat',
  startAt: '2030-01-02T01:00:00.000Z',
  endAt: '2030-01-02T02:00:00.000Z',
);
Map<String, dynamic> bookingJson({
  String patientId = 'patient-a',
  String status = 'Requested',
}) => {
  'id': 'booking-a',
  'patientId': patientId,
  'service': <String, dynamic>{
    'id': demoService.id,
    'name': demoService.name,
    'description': demoService.description,
    'version': 1,
    'synthetic': true,
    'coverageProvince': 'DKI Jakarta',
    'coverageCities': ['Jakarta Pusat'],
    'timezone': 'Asia/Jakarta',
  },
  'address': <String, dynamic>{
    'fullAddress': bookingInput.fullAddress,
    'kelurahan': bookingInput.kelurahan,
    'kecamatan': bookingInput.kecamatan,
    'city': bookingInput.city,
  },
  'preferredWindow': <String, dynamic>{
    'startAt': bookingInput.startAt,
    'endAt': bookingInput.endAt,
    'timezone': 'Asia/Jakarta',
  },
  'visitNote': '',
  'status': status,
  'version': 1,
  'assignedStaff': null,
  'confirmedSlot': null,
  'completedAt': null,
  'completionNote': null,
  'createdAt': '2026-10-25T12:00:00.000Z',
  'updatedAt': '2026-10-25T12:00:00.000Z',
  'timeline': <dynamic>[],
};
Booking bookingFixture({String patientId = 'patient-a'}) =>
    Booking.fromJson(bookingJson(patientId: patientId));
