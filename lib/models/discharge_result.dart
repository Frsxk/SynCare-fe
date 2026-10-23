/// Clinical episode data embedded in an F1 discharge result.
class Episode {
  const Episode({
    this.diagnosis,
    this.medications = const <String>[],
    this.instructions = const <String>[],
    this.followupNeeds = const <String>[],
    this.lengthOfStayDays,
    this.admissionType,
    this.comorbidityCount,
    this.admissionsPrior12m,
  });

  final String? diagnosis;
  final List<String> medications;
  final List<String> instructions;
  final List<String> followupNeeds;
  final int? lengthOfStayDays;
  final String? admissionType;
  final int? comorbidityCount;
  final int? admissionsPrior12m;

  factory Episode.fromJson(Map<String, dynamic> json) {
    return Episode(
      diagnosis: _nullableString(json['diagnosis']),
      medications: _stringList(json['medications']),
      instructions: _stringList(json['instructions']),
      followupNeeds: _stringList(json['followup_needs']),
      lengthOfStayDays: _nullableInt(json['length_of_stay_days']),
      admissionType: _nullableString(json['admission_type']),
      comorbidityCount: _nullableInt(json['comorbidity_count']),
      admissionsPrior12m: _nullableInt(json['admissions_prior_12m']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'diagnosis': diagnosis,
      'medications': medications,
      'instructions': instructions,
      'followup_needs': followupNeeds,
      'length_of_stay_days': lengthOfStayDays,
      'admission_type': admissionType,
      'comorbidity_count': comorbidityCount,
      'admissions_prior_12m': admissionsPrior12m,
    };
  }
}

/// One scored risk factor from F1.
class RiskFactor {
  const RiskFactor({
    required this.name,
    this.value,
    this.threshold,
    this.points = 0,
    this.met = false,
  });

  final String name;
  final Object? value;
  final Object? threshold;
  final int points;
  final bool met;

  factory RiskFactor.fromJson(String name, Map<String, dynamic> json) {
    return RiskFactor(
      name: name,
      value: json['value'],
      threshold: json['threshold'],
      points: _int(json['points']),
      met: _bool(json['met']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'value': value,
      'threshold': threshold,
      'points': points,
      'met': met,
    };
  }
}

/// Parsed F1 output.
class DischargeResult {
  const DischargeResult({
    this.episode = const Episode(),
    this.score = 0,
    this.tier = '',
    this.riskFactors = const <String, RiskFactor>{},
    this.rationale = '',
    this.label = '',
    this.missingFields = const <String>[],
    this.notClinicallyValidated = false,
    this.syntheticDemoOnly = false,
    this.disclaimer = '',
    this.rawJson = const <String, dynamic>{},
  });

  final Episode episode;
  final int score;
  final String tier;
  final Map<String, RiskFactor> riskFactors;
  final String rationale;
  final String label;
  final List<String> missingFields;
  final bool notClinicallyValidated;
  final bool syntheticDemoOnly;
  final String disclaimer;
  final Map<String, dynamic> rawJson;

  factory DischargeResult.fromJson(Map<String, dynamic> json) {
    final episodeJson = _mapOrNull(json['episode']);
    final factorsJson = _mapOrNull(json['risk_factors']);
    return DischargeResult(
      episode: episodeJson == null
          ? const Episode()
          : Episode.fromJson(episodeJson),
      score: _int(json['score']),
      tier: _string(json['tier']),
      riskFactors: <String, RiskFactor>{
        if (factorsJson != null)
          for (final entry in factorsJson.entries)
            entry.key: RiskFactor.fromJson(
              entry.key,
              _mapOrNull(entry.value) ?? const <String, dynamic>{},
            ),
      },
      rationale: _string(json['rationale']),
      label: _string(json['label']),
      missingFields: _stringList(json['missing_fields']),
      notClinicallyValidated: _bool(json['not_clinically_validated']),
      syntheticDemoOnly: _bool(json['synthetic_demo_only']),
      disclaimer: _string(json['disclaimer']),
      rawJson: json,
    );
  }

  /// The exact object F3 expects as `f1_scored_output`.
  Map<String, dynamic> toF1ScoredOutput() {
    final rawEpisode = _mapOrNull(rawJson['episode']);
    final rawFactors = _mapOrNull(rawJson['risk_factors']);
    return <String, dynamic>{
      'episode': rawEpisode ?? episode.toJson(),
      'score': rawJson['score'] ?? score,
      'tier': rawJson['tier'] ?? tier,
      'risk_factors':
          rawFactors ??
          <String, dynamic>{
            for (final entry in riskFactors.entries)
              entry.key: entry.value.toJson(),
          },
      'rationale': rawJson['rationale'] ?? rationale,
      'label': rawJson['label'] ?? label,
    };
  }
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

bool _bool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is String) {
    return value.toLowerCase() == 'true';
  }
  return false;
}

int _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  if (value is String) {
    return int.tryParse(value) ?? double.tryParse(value)?.round() ?? 0;
  }
  return 0;
}

int? _nullableInt(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  if (value is String) {
    return int.tryParse(value) ?? double.tryParse(value)?.round();
  }
  return null;
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
