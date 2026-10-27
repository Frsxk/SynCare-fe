import '../core/api_exception.dart';
import 'checkin_record.dart';

Map<String, dynamic> patientObject(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const InvalidResponseException();
  }
  return value;
}

String patientText(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    throw const InvalidResponseException();
  }
  return value;
}

int patientVersion(Object? value) {
  if (value is! int || value < 1) {
    throw const InvalidResponseException();
  }
  return value;
}

class PatientProfile {
  const PatientProfile({
    required this.id,
    required this.displayName,
    required this.recordedCondition,
    required this.version,
  });
  final String id;
  final String displayName;
  final String? recordedCondition;
  final int version;
  factory PatientProfile.fromJson(Object? value) {
    final json = patientObject(value);
    final condition = json['recordedCondition'];
    if (condition != null && condition is! String) {
      throw const InvalidResponseException();
    }
    return PatientProfile(
      id: patientText(json['id']),
      displayName: patientText(patientObject(json['profile'])['displayName']),
      recordedCondition: condition as String?,
      version: patientVersion(json['version']),
    );
  }
}

class ConfirmedRiskEvidence {
  const ConfirmedRiskEvidence({
    required this.category,
    required this.score,
    required this.sourceVersion,
    required this.assessmentId,
    required this.dischargeId,
    required this.confirmedAt,
    required this.confirmedBy,
    required this.applicable,
    required this.disclaimer,
  });
  final String category;
  final num score;
  final int sourceVersion;
  final String assessmentId;
  final String dischargeId;
  final String confirmedAt;
  final String confirmedBy;
  final bool applicable;
  final String disclaimer;
  factory ConfirmedRiskEvidence.fromJson(Object? value) {
    final json = patientObject(value), score = json['score'];
    final category = patientText(json['category']);
    if (!['LOW', 'MEDIUM', 'HIGH'].contains(category) ||
        score is! num ||
        !score.isFinite ||
        json['applicable'] is! bool) {
      throw const InvalidResponseException();
    }
    final confirmedAt = patientText(json['confirmedAt']);
    if (DateTime.tryParse(confirmedAt) == null) {
      throw const InvalidResponseException();
    }
    return ConfirmedRiskEvidence(
      category: category,
      score: score,
      sourceVersion: patientVersion(json['sourceVersion']),
      assessmentId: patientText(json['assessmentId']),
      dischargeId: patientText(json['dischargeId']),
      confirmedAt: confirmedAt,
      confirmedBy: patientText(json['confirmedBy']),
      applicable: json['applicable'] as bool,
      disclaimer: patientText(json['disclaimer']),
    );
  }
}

class ConfirmedRisk {
  const ConfirmedRisk({
    required this.status,
    required this.current,
    required this.previous,
  });
  final String status;
  final ConfirmedRiskEvidence? current;
  final ConfirmedRiskEvidence? previous;
  factory ConfirmedRisk.fromJson(Object? value) {
    final json = patientObject(value), status = patientText(json['status']);
    if (!['confirmed', 'unconfirmed', 'needs_reassessment'].contains(status)) {
      throw const InvalidResponseException();
    }
    final current = json['current'] == null
        ? null
        : ConfirmedRiskEvidence.fromJson(json['current']);
    final previous = json['previous'] == null
        ? null
        : ConfirmedRiskEvidence.fromJson(json['previous']);
    if ((status == 'confirmed') != (current != null) ||
        current?.applicable == false ||
        previous?.applicable == true ||
        status == 'needs_reassessment' && previous == null) {
      throw const InvalidResponseException();
    }
    return ConfirmedRisk(status: status, current: current, previous: previous);
  }
}

class PatientOverview {
  const PatientOverview({
    required this.profile,
    required this.confirmedRisk,
    required this.sourceVersion,
    this.latestReport,
  });
  final PatientProfile profile;
  final ConfirmedRisk confirmedRisk;
  final int? sourceVersion;
  final CheckinRecord? latestReport;
  factory PatientOverview.fromJson(Object? value) {
    final json = patientObject(value);
    for (final key in [
      'currentPlan',
      'activeBookingCounts',
      'openAlertCounts',
    ]) {
      final source = patientObject(json[key]);
      if (source['availability'] != 'unavailable' ||
          source['reason'] != 'domain_source_not_connected') {
        throw const InvalidResponseException();
      }
    }
    final sourceVersion = json['currentDischarge'] == null
        ? null
        : patientVersion(patientObject(json['currentDischarge'])['version']);
    final risk = ConfirmedRisk.fromJson(json['confirmedRisk']);
    if (risk.current != null &&
        (risk.current!.sourceVersion != sourceVersion ||
            risk.current!.dischargeId !=
                patientObject(json['currentDischarge'])['id'])) {
      throw const InvalidResponseException();
    }
    final profile = PatientProfile.fromJson(json['profile']);
    final report = json['latestReport'] == null
        ? null
        : CheckinRecord.fromJson(json['latestReport']);
    if (report != null && report.patientId != profile.id) {
      throw const InvalidResponseException();
    }
    return PatientOverview(
      profile: profile,
      confirmedRisk: risk,
      sourceVersion: sourceVersion,
      latestReport: report,
    );
  }
}
