import 'dart:convert';
import '../core/api_exception.dart';
import 'approved_plan.dart';
import 'patient.dart';

class VerifiedCarePlan {
  const VerifiedCarePlan({
    required this.id,
    required this.record,
    required this.reviewId,
    required this.sourceVersion,
    required this.applicable,
    required this.approvedLabel,
  });
  final String id, reviewId, approvedLabel;
  final ApprovedPlanRecord record;
  final int sourceVersion;
  final bool applicable;
  factory VerifiedCarePlan.fromJson(Object? value) {
    final v = patientObject(value);
    if (v.keys.any(
      (k) => !{
        'id',
        'patientId',
        'reviewId',
        'approvedAt',
        'plan',
        'source',
        'createdAt',
      }.contains(k),
    )) {
      throw const InvalidResponseException();
    }
    final patientId = patientText(v['patientId']),
        p = patientObject(v['plan']),
        source = patientObject(v['source']);
    final timestamp = patientText(v['approvedAt']),
        at = DateTime.tryParse(timestamp);
    if (at == null ||
        !RegExp(
          r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?(?:Z|[+-]\d{2}:\d{2})$',
        ).hasMatch(timestamp) ||
        p.keys.any(
          (k) => !{
            'patient_id',
            'plan_text',
            'satuseshat',
            'tier',
            'care_intensity',
            'status',
            'label',
            'missing_facts',
            'disclaimer',
          }.contains(k),
        ) ||
        p['patient_id'] != patientId ||
        p['status'] != 'DRAFT pending human approval' ||
        p['label'] != 'demo-heuristic-v1' ||
        !['LOW', 'MEDIUM', 'HIGH'].contains(p['tier']) ||
        p['missing_facts'] is! List ||
        (p['missing_facts'] as List).isNotEmpty ||
        p['care_intensity'] is! List ||
        (p['care_intensity'] as List).any(
          (i) => i is! String || i.trim().isEmpty,
        ) ||
        source['sourceVersion'] is! int ||
        (source['sourceVersion'] as int) < 1 ||
        source['applicable'] is! bool ||
        source.keys.any(
          (k) => !{
            'assessmentId',
            'dischargeId',
            'sourceVersion',
            'applicable',
          }.contains(k),
        )) {
      throw const InvalidResponseException();
    }
    final calendar = timestamp.substring(0, 10);
    if (DateTime.tryParse(calendar)?.toIso8601String().substring(0, 10) !=
            calendar ||
        int.parse(timestamp.substring(11, 13)) > 23 ||
        int.parse(timestamp.substring(14, 16)) > 59 ||
        int.parse(timestamp.substring(17, 19)) > 59) {
      throw const InvalidResponseException();
    }
    patientText(p['plan_text']);
    patientText(p['disclaimer']);
    patientText(source['assessmentId']);
    patientText(source['dischargeId']);
    final resources = patientObject(p['satuseshat']);
    if (resources.keys.any(
          (k) => !{'careplan', 'servicerequest', 'task'}.contains(k),
        ) ||
        resources['task'] is! List) {
      throw const InvalidResponseException();
    }
    patientObject(resources['careplan']);
    patientObject(resources['servicerequest']);
    final utc = at.toUtc(),
        label = utc
            .add(const Duration(hours: 7))
            .toIso8601String()
            .substring(0, 16)
            .replaceFirst('T', ' ');
    return VerifiedCarePlan(
      id: patientText(v['id']),
      reviewId: patientText(v['reviewId']),
      sourceVersion: source['sourceVersion'] as int,
      applicable: source['applicable'] as bool,
      approvedLabel: '$label WIB',
      record: ApprovedPlanRecord(
        patientId: patientId,
        plan: ApprovedPlan.fromJson(p),
        approvedAt: utc,
        reviewerNote: '',
        planJsonString: jsonEncode(p),
      ),
    );
  }
}

class VerifiedPlanPage {
  const VerifiedPlanPage(this.plans, this.nextCursor);
  final List<VerifiedCarePlan> plans;
  final String? nextCursor;
  factory VerifiedPlanPage.fromJson(Object? value) {
    final v = patientObject(value), rows = v['data'];
    if (rows is! List ||
        rows.length > 100 ||
        v['nextCursor'] != null && v['nextCursor'] is! String) {
      throw const InvalidResponseException();
    }
    return VerifiedPlanPage(
      rows.map(VerifiedCarePlan.fromJson).toList(growable: false),
      v['nextCursor'] as String?,
    );
  }
}
