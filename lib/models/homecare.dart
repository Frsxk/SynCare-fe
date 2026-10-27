import '../core/api_exception.dart';
import 'patient.dart';

class HomecareService {
  const HomecareService({
    required this.id,
    required this.name,
    required this.description,
    required this.version,
    required this.cities,
  });
  final String id, name, description;
  final int version;
  final List<String> cities;
  factory HomecareService.fromJson(Object? value) {
    final m = patientObject(value);
    if (m['synthetic'] != true ||
        m['coverageProvince'] != 'DKI Jakarta' ||
        m['timezone'] != 'Asia/Jakarta' ||
        m['coverageCities'] is! List) {
      throw const InvalidResponseException();
    }
    final cities = (m['coverageCities'] as List)
        .map(patientText)
        .toList(growable: false);
    if (cities.isEmpty) throw const InvalidResponseException();
    return HomecareService(
      id: patientText(m['id']),
      name: patientText(m['name']),
      description: patientText(m['description']),
      version: patientVersion(m['version']),
      cities: cities,
    );
  }
}

class ServicePage {
  const ServicePage(this.services, this.nextCursor);
  final List<HomecareService> services;
  final String? nextCursor;
  factory ServicePage.fromJson(Object? value) {
    final m = patientObject(value);
    if (m['data'] is! List || !m.containsKey('nextCursor')) {
      throw const InvalidResponseException();
    }
    return ServicePage(
      (m['data'] as List).map(HomecareService.fromJson).toList(growable: false),
      m['nextCursor'] == null ? null : patientText(m['nextCursor']),
    );
  }
}

enum BookingStatus {
  requested,
  underReview,
  scheduled,
  completed,
  cancelled,
  rejected;

  static BookingStatus parse(Object? value) => switch (value) {
    'Requested' => requested,
    'Under Review' => underReview,
    'Scheduled' => scheduled,
    'Completed' => completed,
    'Cancelled' => cancelled,
    'Rejected' => rejected,
    _ => throw const InvalidResponseException(),
  };
  String get label => switch (this) {
    requested => 'Diajukan',
    underReview => 'Sedang ditinjau',
    scheduled => 'Terjadwal',
    completed => 'Selesai',
    cancelled => 'Dibatalkan',
    rejected => 'Ditolak',
  };
}

class BookingInput {
  const BookingInput({
    required this.serviceId,
    required this.fullAddress,
    required this.kelurahan,
    required this.kecamatan,
    required this.city,
    required this.startAt,
    required this.endAt,
    this.visitNote = '',
  });
  final String serviceId,
      fullAddress,
      kelurahan,
      kecamatan,
      city,
      startAt,
      endAt,
      visitNote;
  Map<String, Object?> toJson() => {
    'serviceId': serviceId,
    'address': {
      'fullAddress': fullAddress,
      'kelurahan': kelurahan,
      'kecamatan': kecamatan,
      'city': city,
    },
    'preferredWindow': {
      'startAt': startAt,
      'endAt': endAt,
      'timezone': 'Asia/Jakarta',
    },
    'visitNote': visitNote,
  };
  static BookingInput fromFields(String serviceId, Map<String, String> fields) {
    String text(String key, int max) {
      final v = (fields[key] ?? '').trim();
      if (v.isEmpty || v.length > max) {
        throw const ValidationException(
          'Lengkapi alamat, wilayah, tanggal dan rentang jam kunjungan.',
        );
      }
      return v;
    }

    final date = text('date', 10),
        start = text('start', 5),
        end = text('end', 5);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
        !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(start) ||
        !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(end)) {
      throw const ValidationException(
        'Gunakan tanggal YYYY-MM-DD dan jam HH:MM dalam WIB.',
      );
    }
    DateTime instant(String time) {
      final v = DateTime.tryParse('${date}T$time:00+07:00');
      if (v == null ||
          v
                  .toUtc()
                  .add(const Duration(hours: 7))
                  .toIso8601String()
                  .substring(0, 10) !=
              date) {
        throw const ValidationException('Tanggal kunjungan tidak valid.');
      }
      return v.toUtc();
    }

    final from = instant(start), until = instant(end);
    if (!until.isAfter(from) || !from.isAfter(DateTime.now().toUtc())) {
      throw const ValidationException(
        'Pilih waktu mendatang dengan jam selesai setelah jam mulai.',
      );
    }
    final note = fields['note'] ?? '';
    if (note.length > 2000) {
      throw const ValidationException('Catatan maksimal 2000 karakter.');
    }
    return BookingInput(
      serviceId: serviceId,
      fullAddress: text('address', 1000),
      kelurahan: text('kelurahan', 160),
      kecamatan: text('kecamatan', 160),
      city: text('city', 160),
      startAt: from.toIso8601String(),
      endAt: until.toIso8601String(),
      visitNote: note.trim(),
    );
  }
}

String bookingTime(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw const InvalidResponseException();
  final text = parsed.toUtc().add(const Duration(hours: 7)).toIso8601String();
  return '${text.substring(0, 10)} ${text.substring(11, 16)} WIB';
}

class Booking {
  const Booking({
    required this.id,
    required this.patientId,
    required this.service,
    required this.status,
    required this.version,
    required this.fullAddress,
    required this.city,
    required this.startLabel,
    required this.endLabel,
    required this.createdLabel,
    required this.hasConfirmedSlot,
    required this.confirmedSlot,
    required this.assignedStaff,
    required this.timeline,
    required this.completedAt,
    required this.completionNote,
    required this.kelurahan,
    required this.kecamatan,
    required this.visitNote,
  });
  final String id,
      patientId,
      fullAddress,
      city,
      startLabel,
      endLabel,
      createdLabel;
  final HomecareService service;
  final BookingStatus status;
  final int version;
  final bool hasConfirmedSlot;
  final BookingWindow? confirmedSlot;
  final AssignedHomecareStaff? assignedStaff;
  final List<BookingEvent> timeline;
  final String? completedAt, completionNote;
  final String kelurahan, kecamatan, visitNote;
  bool get canCancel =>
      status == BookingStatus.requested || status == BookingStatus.underReview;
  factory Booking.fromJson(Object? value) {
    final m = patientObject(value),
        address = patientObject(m['address']),
        window = patientObject(m['preferredWindow']);
    final status = BookingStatus.parse(m['status']);
    if (window['timezone'] != 'Asia/Jakarta' ||
        !m.containsKey('confirmedSlot') ||
        !m.containsKey('assignedStaff') ||
        m['timeline'] is! List) {
      throw const InvalidResponseException();
    }
    final hasSlot = m['confirmedSlot'] != null,
        hasStaff = m['assignedStaff'] != null;
    if (hasSlot != hasStaff ||
        ((status == BookingStatus.requested ||
                status == BookingStatus.underReview ||
                status == BookingStatus.rejected) &&
            hasSlot) ||
        ((status == BookingStatus.scheduled ||
                status == BookingStatus.completed) &&
            !hasSlot)) {
      throw const InvalidResponseException();
    }
    final start = patientText(window['startAt']),
        end = patientText(window['endAt']);
    if (DateTime.tryParse(start) == null ||
        DateTime.tryParse(end) == null ||
        !DateTime.parse(end).isAfter(DateTime.parse(start))) {
      throw const InvalidResponseException();
    }
    if (!m.containsKey('completedAt') ||
        !m.containsKey('completionNote') ||
        m['visitNote'] is! String) {
      throw const InvalidResponseException();
    }
    final completionTime = m['completedAt'] == null
        ? null
        : bookingTime(patientText(m['completedAt']));
    final note = m['completionNote'] == null
        ? null
        : patientText(m['completionNote']);
    if (status == BookingStatus.completed
        ? completionTime == null || note == null
        : completionTime != null || note != null) {
      throw const InvalidResponseException();
    }
    return Booking(
      id: patientText(m['id']),
      patientId: patientText(m['patientId']),
      service: HomecareService.fromJson(m['service']),
      status: status,
      version: patientVersion(m['version']),
      fullAddress: patientText(address['fullAddress']),
      city: patientText(address['city']),
      startLabel: bookingTime(start),
      endLabel: bookingTime(end),
      createdLabel: bookingTime(patientText(m['createdAt'])),
      hasConfirmedSlot: hasSlot,
      confirmedSlot: hasSlot
          ? BookingWindow.fromJson(m['confirmedSlot'])
          : null,
      assignedStaff: hasStaff
          ? AssignedHomecareStaff.fromJson(m['assignedStaff'])
          : null,
      timeline: (m['timeline'] as List)
          .map(BookingEvent.fromJson)
          .toList(growable: false),
      completedAt: completionTime,
      completionNote: note,
      kelurahan: patientText(address['kelurahan']),
      kecamatan: patientText(address['kecamatan']),
      visitNote: m['visitNote'] as String,
    );
  }
}

class BookingWindow {
  const BookingWindow(this.startLabel, this.endLabel);
  final String startLabel, endLabel;
  factory BookingWindow.fromJson(Object? value) {
    final m = patientObject(value),
        start = patientText(m['startAt']),
        end = patientText(m['endAt']);
    final a = DateTime.tryParse(start), b = DateTime.tryParse(end);
    if (m['timezone'] != 'Asia/Jakarta' ||
        a == null ||
        b == null ||
        !b.isAfter(a)) {
      throw const InvalidResponseException();
    }
    return BookingWindow(bookingTime(start), bookingTime(end));
  }
}

class AssignedHomecareStaff {
  const AssignedHomecareStaff(this.id, this.displayName);
  final String id, displayName;
  factory AssignedHomecareStaff.fromJson(Object? value) {
    final m = patientObject(value);
    return AssignedHomecareStaff(
      patientText(m['id']),
      patientText(m['displayName']),
    );
  }
}

class BookingEvent {
  const BookingEvent({
    required this.id,
    required this.status,
    required this.recordedLabel,
    required this.actorId,
    required this.reason,
  });
  final String id, recordedLabel, actorId;
  final BookingStatus status;
  final String? reason;
  factory BookingEvent.fromJson(Object? value) {
    final m = patientObject(value);
    if (m['internalNote'] != null ||
        !m.containsKey('reason') ||
        !m.containsKey('fromStatus')) {
      throw const InvalidResponseException();
    }
    patientVersion(m['version']);
    if (m['fromStatus'] != null) {
      BookingStatus.parse(m['fromStatus']);
    }
    return BookingEvent(
      id: patientText(m['id']),
      status: BookingStatus.parse(m['toStatus']),
      recordedLabel: bookingTime(patientText(m['occurredAt'])),
      actorId: patientText(m['actorId']),
      reason: m['reason'] == null ? null : patientText(m['reason']),
    );
  }
}

class BookingPage {
  const BookingPage(this.bookings, this.nextCursor);
  final List<Booking> bookings;
  final String? nextCursor;
  factory BookingPage.fromJson(Object? value) {
    final m = patientObject(value);
    if (m['data'] is! List || !m.containsKey('nextCursor')) {
      throw const InvalidResponseException();
    }
    return BookingPage(
      (m['data'] as List).map(Booking.fromJson).toList(growable: false),
      m['nextCursor'] == null ? null : patientText(m['nextCursor']),
    );
  }
}
