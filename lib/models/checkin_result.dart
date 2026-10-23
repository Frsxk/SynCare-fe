class CheckinAdjustment {
  const CheckinAdjustment({
    this.condition = '',
    this.applied = false,
    this.points = 0,
  });

  final String condition;
  final bool applied;
  final int points;

  factory CheckinAdjustment.fromJson(Map<String, dynamic> json) {
    return CheckinAdjustment(
      condition: _string(json['condition']),
      applied: _bool(json['applied']),
      points: _int(json['points']),
    );
  }
}

/// Parsed F2 output, covering both the routine and escalation branches.
class CheckinResult {
  const CheckinResult({
    this.action = '',
    this.reason,
    this.patientId,
    this.baselineScore,
    this.baselineTier,
    this.adjustments = const <CheckinAdjustment>[],
    this.score = 0,
    this.tier = '',
    this.tierChanged = false,
    this.nextCheckinDays,
    this.label = '',
    this.disclaimer = '',
    this.raw = const <String, dynamic>{},
  });

  final String action;
  final String? reason;
  final String? patientId;
  final int? baselineScore;
  final String? baselineTier;
  final List<CheckinAdjustment> adjustments;
  final int score;
  final String tier;
  final bool tierChanged;
  final int? nextCheckinDays;
  final String label;
  final String disclaimer;
  final Map<String, dynamic> raw;

  bool get isEscalation => action == 'escalate_immediately';

  bool get isTierChange {
    if (tierChanged) {
      return true;
    }
    final previous = baselineTier;
    return previous != null &&
        previous.isNotEmpty &&
        tier.isNotEmpty &&
        previous.toUpperCase() != tier.toUpperCase();
  }

  factory CheckinResult.fromJson(Map<String, dynamic> json) {
    final adjustmentsJson = json['adjustments'];
    return CheckinResult(
      action: _string(json['action']),
      reason: _nullableString(json['reason']),
      patientId: _nullableString(json['patient_id']),
      baselineScore: _nullableInt(json['baseline_score']),
      baselineTier: _nullableString(json['baseline_tier']),
      adjustments: <CheckinAdjustment>[
        if (adjustmentsJson is List)
          for (final item in adjustmentsJson)
            if (item is Map)
              CheckinAdjustment.fromJson(
                item.map((key, value) => MapEntry(key.toString(), value)),
              ),
      ],
      score: _int(json['score']),
      tier: _string(json['tier']),
      tierChanged: _bool(json['tier_changed']),
      nextCheckinDays: _nullableInt(json['next_checkin_days']),
      label: _string(json['label']),
      disclaimer: _string(json['disclaimer']),
      raw: json,
    );
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
