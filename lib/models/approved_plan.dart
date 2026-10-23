import 'dart:convert';

import '../core/api_exception.dart';
import 'plan_draft.dart';

/// The parsed `plan_json` of an approved plan.
///
/// It is a [PlanDraft] because the review database stores the F3 draft
/// unchanged; approval is represented by the row existing, not by [status].
class ApprovedPlan extends PlanDraft {
  const ApprovedPlan({
    super.planText,
    super.satuseshat,
    super.patientId,
    super.tier,
    super.careIntensity,
    super.status,
    super.label,
    super.missingFacts,
    super.disclaimer,
    super.rawJson,
  });

  factory ApprovedPlan.fromJson(Map<String, dynamic> json) {
    final draft = PlanDraft.fromJson(json);
    return ApprovedPlan(
      planText: draft.planText,
      satuseshat: draft.satuseshat,
      patientId: draft.patientId,
      tier: draft.tier,
      careIntensity: draft.careIntensity,
      status: draft.status,
      label: draft.label,
      missingFacts: draft.missingFacts,
      disclaimer: draft.disclaimer,
      rawJson: draft.rawJson,
    );
  }
}

/// One row of `GET /api/v1/plans`.
class ApprovedPlanRecord {
  const ApprovedPlanRecord({
    required this.patientId,
    required this.plan,
    required this.approvedAt,
    required this.reviewerNote,
    required this.planJsonString,
  });

  final String patientId;
  final ApprovedPlan plan;
  final DateTime approvedAt;
  final String reviewerNote;
  final String planJsonString;

  factory ApprovedPlanRecord.fromJson(Map<String, dynamic> json) {
    final rawPlanJson = json['plan_json'];
    final ApprovedPlan plan;
    final String planJsonString;
    if (rawPlanJson is Map) {
      plan = ApprovedPlan.fromJson(
        rawPlanJson.map((key, value) => MapEntry(key.toString(), value)),
      );
      planJsonString = jsonEncode(rawPlanJson);
    } else if (rawPlanJson is String && rawPlanJson.trim().isNotEmpty) {
      planJsonString = rawPlanJson;
      plan = _parsePlanJson(rawPlanJson);
    } else {
      throw const InvalidResponseException(
        'Data rencana tidak memuat plan_json yang valid.',
      );
    }

    return ApprovedPlanRecord(
      patientId: _string(
        json['patientId'] ?? json['patient_id'] ?? plan.patientId,
      ),
      plan: plan,
      approvedAt: _date(json['approved_at']),
      reviewerNote: _string(json['reviewer_note']),
      planJsonString: planJsonString,
    );
  }
}

ApprovedPlan _parsePlanJson(String value) {
  Object? decoded;
  try {
    decoded = jsonDecode(value);
  } on FormatException {
    throw const InvalidResponseException(
      'Data rencana tidak memuat plan_json yang valid.',
    );
  }
  if (decoded is String) {
    try {
      decoded = jsonDecode(decoded);
    } on FormatException {
      throw const InvalidResponseException(
        'Data rencana tidak memuat plan_json yang valid.',
      );
    }
  }
  final map = _mapOrNull(decoded);
  if (map == null) {
    throw const InvalidResponseException(
      'Data rencana tidak memuat plan_json yang valid.',
    );
  }
  return ApprovedPlan.fromJson(map);
}

/// One entry of the audit trail.
class AuditEntry {
  const AuditEntry({
    this.action = '',
    this.actor = '',
    required this.timestamp,
  });

  final String action;
  final String actor;
  final DateTime timestamp;

  factory AuditEntry.fromJson(Map<String, dynamic> json) {
    return AuditEntry(
      action: _string(json['action']),
      actor: _string(json['actor']),
      timestamp: _date(json['timestamp']),
    );
  }
}

/// Response of `GET /api/v1/plans`.
class PlansResponse {
  const PlansResponse({
    this.plans = const <ApprovedPlanRecord>[],
    this.audit = const <AuditEntry>[],
  });

  final List<ApprovedPlanRecord> plans;
  final List<AuditEntry> audit;

  factory PlansResponse.fromJson(Map<String, dynamic> json) {
    final plansJson = json['plans'];
    final auditJson = json['audit'];
    return PlansResponse(
      plans: <ApprovedPlanRecord>[
        if (plansJson is List)
          for (final item in plansJson)
            if (item is Map)
              ApprovedPlanRecord.fromJson(
                item.map((key, value) => MapEntry(key.toString(), value)),
              ),
      ],
      audit: <AuditEntry>[
        if (auditJson is List)
          for (final item in auditJson)
            if (item is Map)
              AuditEntry.fromJson(
                item.map((key, value) => MapEntry(key.toString(), value)),
              ),
      ],
    );
  }
}

String _string(Object? value) {
  if (value is String) {
    return value;
  }
  return value?.toString() ?? '';
}

Map<String, dynamic>? _mapOrNull(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return null;
}

DateTime _date(Object? value) {
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      return parsed;
    }
  }
  return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}
