import '../core/api_exception.dart';
import 'patient.dart';
import 'checkin_result.dart';

enum ProcessingState {
  pending,
  blockedBaseline,
  running,
  succeeded,
  invalid,
  failed,
  unknown;

  static ProcessingState parse(Object? value) => switch (value) {
    'PENDING' => pending,
    'BLOCKED_BASELINE' => blockedBaseline,
    'RUNNING' => running,
    'SUCCEEDED' => succeeded,
    'INVALID' => invalid,
    'FAILED' => failed,
    'UNKNOWN' => unknown,
    _ => throw const InvalidResponseException(),
  };
  String get label => switch (this) {
    pending => 'Laporan tersimpan, menunggu analisis.',
    running => 'Laporan tersimpan, sedang dianalisis.',
    blockedBaseline =>
      'Laporan tersimpan. Menunggu penilaian awal dari perawat.',
    succeeded => 'Analisis selesai.',
    invalid => 'Hasil analisis tidak valid. Laporan tetap tersimpan.',
    failed => 'Analisis belum berhasil. Laporan tetap tersimpan.',
    unknown =>
      'Hasil analisis belum dapat dipastikan. Laporan Anda tetap tersimpan.',
  };
  bool get isPending => this == pending || this == running;
}

sealed class CheckinOutcome {
  const CheckinOutcome();
}

class UrgentCheckinOutcome extends CheckinOutcome {
  const UrgentCheckinOutcome(this.reason);
  final String reason;
}

class RoutineCheckinOutcome extends CheckinOutcome {
  const RoutineCheckinOutcome(this.result);
  final CheckinResult result;
}

String checkinTime(Object? value) {
  final text = patientText(value);
  if (DateTime.tryParse(text) == null) throw const InvalidResponseException();
  return text;
}

num checkinNumber(Object? value) {
  if (value is! num || !value.isFinite || value < 0) {
    throw const InvalidResponseException();
  }
  return value;
}

class CheckinBaseline {
  const CheckinBaseline({
    required this.assessmentId,
    required this.score,
    required this.sourceVersion,
    required this.applicable,
  });
  final String assessmentId;
  final num score;
  final int sourceVersion;
  final bool applicable;
  factory CheckinBaseline.fromJson(Object? value) {
    final json = patientObject(value);
    patientText(json['confirmationId']);
    patientText(json['dischargeId']);
    if (json['applicable'] is! bool) throw const InvalidResponseException();
    return CheckinBaseline(
      assessmentId: patientText(json['assessmentId']),
      score: checkinNumber(json['score']),
      sourceVersion: patientVersion(json['sourceVersion']),
      applicable: json['applicable'] as bool,
    );
  }
}

class CheckinRecord {
  const CheckinRecord({
    required this.id,
    required this.patientId,
    required this.message,
    required this.createdAt,
    required this.processing,
    required this.baseline,
    required this.outcome,
    required this.alertEvidence,
  });
  final String id, patientId, message, createdAt, alertEvidence;
  final ProcessingState processing;
  final CheckinBaseline? baseline;
  final CheckinOutcome? outcome;
  factory CheckinRecord.fromJson(Object? value) {
    final json = patientObject(value), p = patientObject(json['processing']);
    final id = patientText(json['id']),
        patientId = patientText(json['patientId']);
    patientVersion(json['version']);
    patientText(json['submittedBy']);
    patientText(p['id']);
    patientVersion(p['version']);
    checkinTime(p['updatedAt']);
    final processing = ProcessingState.parse(p['state']);
    final baseline = json['baseline'] == null
        ? null
        : CheckinBaseline.fromJson(json['baseline']);
    final alert = patientText(json['alertEvidence']);
    if (!['not_applicable', 'queued', 'unavailable'].contains(alert)) {
      throw const InvalidResponseException();
    }
    CheckinOutcome? outcome;
    if (json['outcome'] != null) {
      final o = patientObject(json['outcome']),
          action = patientText(o['action']);
      if (action == 'escalate_immediately') {
        if (o.keys.any((k) => !['action', 'reason'].contains(k))) {
          throw const InvalidResponseException();
        }
        outcome = UrgentCheckinOutcome(patientText(o['reason']));
      } else {
        if (!['continue_monitoring', 'trigger_plan_review'].contains(action) ||
            o['patient_id'] != patientId ||
            o['baseline_score'] != baseline?.score ||
            !['LOW', 'MEDIUM', 'HIGH'].contains(o['tier']) ||
            !['LOW', 'MEDIUM', 'HIGH'].contains(o['baseline_tier']) ||
            o['tier_changed'] is! bool) {
          throw const InvalidResponseException();
        }
        checkinNumber(o['score']);
        checkinNumber(o['baseline_score']);
        patientVersion(o['next_checkin_days']);
        patientText(o['label']);
        patientText(o['disclaimer']);
        final adjustments = o['adjustments'];
        if (adjustments is! List) throw const InvalidResponseException();
        for (final value in adjustments) {
          final a = patientObject(value);
          patientText(a['condition']);
          if (a['applied'] is! bool ||
              a['points'] is! num ||
              !(a['points'] as num).isFinite) {
            throw const InvalidResponseException();
          }
        }
        final extraction = patientObject(o['extraction']);
        if (extraction['red_flag'] != false ||
            extraction['quote_of_red_flag'] != '' ||
            extraction['symptoms'] is! List ||
            (extraction['symptoms'] as List).any((s) => s is! String) ||
            ![
              'regular',
              'irregular',
              'unknown',
            ].contains(extraction['medication_adherence'])) {
          throw const InvalidResponseException();
        }
        outcome = RoutineCheckinOutcome(CheckinResult.fromJson(o));
      }
    }
    if ((processing == ProcessingState.succeeded) != (outcome != null)) {
      throw const InvalidResponseException();
    }
    return CheckinRecord(
      id: id,
      patientId: patientId,
      message: patientText(json['message']),
      createdAt: checkinTime(json['createdAt']),
      processing: processing,
      baseline: baseline,
      outcome: outcome,
      alertEvidence: alert,
    );
  }
}

class CheckinPage {
  const CheckinPage(this.records, this.nextCursor);
  final List<CheckinRecord> records;
  final String? nextCursor;
  factory CheckinPage.fromJson(Object? value) {
    final json = patientObject(value),
        items = json['data'],
        cursor = json['nextCursor'];
    if (items is! List || cursor != null && cursor is! String) {
      throw const InvalidResponseException();
    }
    return CheckinPage(
      items.map(CheckinRecord.fromJson).toList(growable: false),
      cursor as String?,
    );
  }
}

class EmergencyGuidance {
  const EmergencyGuidance({
    required this.content,
    required this.region,
    required this.source,
    required this.verifiedAt,
    required this.version,
    required this.contacts,
  });
  final String content, region, source, verifiedAt;
  final int version;
  final List<({String label, String number})> contacts;
  factory EmergencyGuidance.fromJson(Object? value) {
    final json = patientObject(value),
        source = patientText(json['source']),
        contacts = json['contacts'];
    if (Uri.tryParse(source)?.scheme != 'https' || contacts is! List) {
      throw const InvalidResponseException();
    }
    return EmergencyGuidance(
      content: patientText(json['content']),
      region: patientText(json['region']),
      source: source,
      verifiedAt: checkinTime(json['verifiedAt']),
      version: patientVersion(json['version']),
      contacts: contacts
          .map((v) {
            final c = patientObject(v);
            if (c['action'] != 'information_only') {
              throw const InvalidResponseException();
            }
            return (
              label: patientText(c['label']),
              number: patientText(c['number']),
            );
          })
          .toList(growable: false),
    );
  }
}
