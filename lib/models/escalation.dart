import '../core/api_exception.dart';
import 'patient.dart';
import 'homecare.dart';

enum EscalationStatus {
  pending,
  acknowledged,
  inProgress,
  resolved;

  static EscalationStatus parse(Object? value) => switch (value) {
    'PENDING_REVIEW' => pending,
    'ACKNOWLEDGED' => acknowledged,
    'IN_PROGRESS' => inProgress,
    'RESOLVED' => resolved,
    _ => throw const InvalidResponseException(),
  };
  String get label => switch (this) {
    pending => 'Menunggu review',
    acknowledged => 'Diakui perawat',
    inProgress => 'Sedang ditindaklanjuti',
    resolved => 'Ditutup',
  };
}

Map<String, dynamic> _safe(Object? value, Set<String> allowed) {
  final result = patientObject(value);
  if (result.keys.any((key) => !allowed.contains(key))) {
    throw const InvalidResponseException();
  }
  return result;
}

String _instant(Object? value) {
  final text = patientText(value), date = DateTime.tryParse(text);
  if (!RegExp(
        r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$',
      ).hasMatch(text) ||
      date == null ||
      date.toUtc().toIso8601String() != text) {
    throw const InvalidResponseException();
  }
  return text;
}

class EscalationEvent {
  const EscalationEvent({
    required this.id,
    required this.version,
    required this.status,
    required this.recordedLabel,
    required this.patientSummary,
  });
  final String id, recordedLabel;
  final int version;
  final EscalationStatus status;
  final String? patientSummary;
  factory EscalationEvent.fromJson(Object? value) {
    final m = _safe(value, {
      'id',
      'version',
      'status',
      'recordedAt',
      'patientSummary',
    });
    return EscalationEvent(
      id: patientText(m['id']),
      version: patientVersion(m['version']),
      status: EscalationStatus.parse(m['status']),
      recordedLabel: bookingTime(_instant(m['recordedAt'])),
      patientSummary: m['patientSummary'] == null
          ? null
          : patientText(m['patientSummary']),
    );
  }
}

class Escalation {
  Escalation({
    required this.id,
    required this.patientId,
    required this.sourceType,
    required this.reportId,
    required this.attemptId,
    required this.requestId,
    required this.reason,
    required this.status,
    required this.version,
    required this.reportedAt,
    required this.outcomeAt,
    required this.createdAt,
    required this.updatedAt,
    required this.acknowledgedAt,
    required this.resolvedAt,
    required this.timeline,
    required this.timelineNextCursor,
  }) : reportedLabel = bookingTime(reportedAt),
       outcomeLabel = outcomeAt == null ? null : bookingTime(outcomeAt),
       acknowledgedLabel = acknowledgedAt == null
           ? null
           : bookingTime(acknowledgedAt),
       resolvedLabel = resolvedAt == null ? null : bookingTime(resolvedAt);
  final String id,
      patientId,
      sourceType,
      reason,
      reportedAt,
      createdAt,
      updatedAt,
      reportedLabel;
  final String? reportId, attemptId, requestId, outcomeAt, outcomeLabel;
  final String? acknowledgedAt,
      resolvedAt,
      acknowledgedLabel,
      resolvedLabel,
      timelineNextCursor;
  final int version;
  final EscalationStatus status;
  final List<EscalationEvent> timeline;

  /// A patient-authored emergency request is not an F2 check-in escalation:
  /// it has no report/attempt evidence and must not be presented as one.
  bool get isPatientRequest => sourceType == 'PATIENT_REQUEST';

  factory Escalation.fromJson(Object? value, {bool detail = false}) {
    final m = _safe(value, {
      'id',
      'patientId',
      'source',
      'urgency',
      'status',
      'version',
      'acknowledgedAt',
      'resolvedAt',
      'createdAt',
      'updatedAt',
      'timeline',
      'timelineNextCursor',
    });
    final source = patientObject(m['source']);
    final sourceType = patientText(source['type']);
    String? reportId;
    String? attemptId;
    String? requestId;
    String? outcomeAt;
    switch (sourceType) {
      case 'F2':
        final f2 = _safe(source, {
          'type',
          'reportId',
          'attemptId',
          'action',
          'reason',
          'reportedAt',
          'outcomeAt',
        });
        if (f2['action'] != 'escalate_immediately') {
          throw const InvalidResponseException();
        }
        reportId = patientText(f2['reportId']);
        attemptId = patientText(f2['attemptId']);
        requestId = null;
        outcomeAt = _instant(f2['outcomeAt']);
      case 'PATIENT_REQUEST':
        final request = _safe(source, {
          'type',
          'requestId',
          'action',
          'reason',
          'reportedAt',
          'outcomeAt',
        });
        if (request['action'] != 'request_immediate_help') {
          throw const InvalidResponseException();
        }
        reportId = null;
        attemptId = null;
        requestId = patientText(request['requestId']);
        // A patient request has no F2 analysis timestamp; absent/null is the
        // normal shape, never a fabricated instant.
        outcomeAt = request['outcomeAt'] == null
            ? null
            : _instant(request['outcomeAt']);
      default:
        throw const InvalidResponseException();
    }
    if (m['urgency'] != 'acute' ||
        (detail &&
            (m['timeline'] is! List || !m.containsKey('timelineNextCursor')))) {
      throw const InvalidResponseException();
    }
    final status = EscalationStatus.parse(m['status']),
        ack = m['acknowledgedAt'] == null
            ? null
            : _instant(m['acknowledgedAt']),
        resolved = m['resolvedAt'] == null ? null : _instant(m['resolvedAt']);
    if ((status == EscalationStatus.pending) != (ack == null) ||
        (status == EscalationStatus.resolved) != (resolved != null)) {
      throw const InvalidResponseException();
    }
    final version = patientVersion(m['version']);
    final timeline = detail
        ? (m['timeline'] as List)
              .map(EscalationEvent.fromJson)
              .toList(growable: false)
        : <EscalationEvent>[];
    if (timeline.length > 100 ||
        timeline.any((e) => e.version > version) ||
        timeline.asMap().entries.any(
          (e) => e.key > 0 && timeline[e.key - 1].version >= e.value.version,
        )) {
      throw const InvalidResponseException();
    }
    return Escalation(
      id: patientText(m['id']),
      patientId: patientText(m['patientId']),
      sourceType: sourceType,
      reportId: reportId,
      attemptId: attemptId,
      requestId: requestId,
      reason: patientText(source['reason']),
      status: status,
      version: version,
      reportedAt: _instant(source['reportedAt']),
      outcomeAt: outcomeAt,
      createdAt: _instant(m['createdAt']),
      updatedAt: _instant(m['updatedAt']),
      acknowledgedAt: ack,
      resolvedAt: resolved,
      timeline: timeline,
      timelineNextCursor: m['timelineNextCursor'] == null
          ? null
          : patientText(m['timelineNextCursor']),
    );
  }
  Escalation withHistory(List<EscalationEvent> events, String? cursor) =>
      Escalation(
        id: id,
        patientId: patientId,
        sourceType: sourceType,
        reportId: reportId,
        attemptId: attemptId,
        requestId: requestId,
        reason: reason,
        status: status,
        version: version,
        reportedAt: reportedAt,
        outcomeAt: outcomeAt,
        createdAt: createdAt,
        updatedAt: updatedAt,
        acknowledgedAt: acknowledgedAt,
        resolvedAt: resolvedAt,
        timeline: events,
        timelineNextCursor: cursor,
      );
}

class EscalationPage {
  const EscalationPage(this.alerts, this.nextCursor);
  final List<Escalation> alerts;
  final String? nextCursor;
  factory EscalationPage.fromJson(Object? value) {
    final m = patientObject(value);
    if (m['data'] is! List ||
        !m.containsKey('nextCursor') ||
        (m['data'] as List).length > 100) {
      throw const InvalidResponseException();
    }
    return EscalationPage(
      (m['data'] as List).map(Escalation.fromJson).toList(growable: false),
      m['nextCursor'] == null ? null : patientText(m['nextCursor']),
    );
  }
}

/// Standard 201 body for `POST /patients/:id/emergencies`:
/// `{"data":{"resource":AlertDetail,"replayed":bool}}`.
class EmergencyRequestResult {
  const EmergencyRequestResult({required this.alert, required this.replayed});
  final Escalation alert;
  final bool replayed;
  factory EmergencyRequestResult.fromJson(
    Object? value, {
    required String patientId,
  }) {
    final data = patientObject(value);
    if (data.keys.any((key) => key != 'resource' && key != 'replayed')) {
      throw const InvalidResponseException();
    }
    final replayed = data['replayed'];
    if (replayed is! bool) {
      throw const InvalidResponseException();
    }
    final alert = Escalation.fromJson(data['resource'], detail: true);
    if (alert.patientId != patientId || !alert.isPatientRequest) {
      throw const InvalidResponseException();
    }
    return EmergencyRequestResult(alert: alert, replayed: replayed);
  }
}
