import 'dart:convert';

class PlanDraft {
  const PlanDraft({
    this.planText = '',
    this.satuseshat = const <String, dynamic>{},
    this.patientId,
    this.tier = '',
    this.careIntensity = const <String>[],
    this.status = '',
    this.label = '',
    this.missingFacts = const <String>[],
    this.disclaimer = '',
    this.rawJson = const <String, dynamic>{},
  });

  final String planText;
  final Map<String, dynamic> satuseshat;
  final String? patientId;
  final String tier;
  final List<String> careIntensity;
  final String status;
  final String label;
  final List<String> missingFacts;
  final String disclaimer;
  final Map<String, dynamic> rawJson;

  factory PlanDraft.fromJson(Map<String, dynamic> json) {
    return PlanDraft(
      planText: _string(json['plan_text']),
      satuseshat: _mapOrNull(json['satuseshat']) ?? const <String, dynamic>{},
      patientId: _nullableString(json['patient_id']),
      tier: _string(json['tier']),
      careIntensity: _careIntensity(json['care_intensity']),
      status: _string(json['status']),
      label: _string(json['label']),
      missingFacts: _stringList(json['missing_facts']),
      disclaimer: _string(json['disclaimer']),
      rawJson: json,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      ...rawJson,
      'plan_text': planText,
      'satuseshat': satuseshat,
      'patient_id': patientId,
      'tier': tier,
      'care_intensity': careIntensity,
      'status': status,
      'label': label,
      'missing_facts': missingFacts,
      'disclaimer': disclaimer,
    };
  }
}

List<String> _careIntensity(Object? value) {
  if (value is List) {
    return _stringList(value);
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return const <String>[];
    }
    if (trimmed.startsWith('[')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          return _stringList(decoded);
        }
      } on FormatException {
        // Fall through to the comma-separated interpretation.
      }
    }
    return trimmed
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  return const <String>[];
}

String _string(Object? value) {
  if (value is String) {
    return value;
  }
  return value?.toString() ?? '';
}

String? _nullableString(Object? value) {
  if (value == null) {
    return null;
  }
  final text = value.toString();
  return text.isEmpty ? null : text;
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .where((item) => item != null)
      .map((item) => item.toString())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
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
