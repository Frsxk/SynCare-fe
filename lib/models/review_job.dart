import 'dart:convert';

/// Response of `POST /api/v1/reviews`.
class ReviewJob {
  const ReviewJob({this.jobId = '', this.flowId = '', this.status = ''});

  final String jobId;
  final String flowId;
  final String status;

  factory ReviewJob.fromJson(Map<String, dynamic> json) {
    return ReviewJob(
      jobId: _string(json['jobId'] ?? json['job_id']),
      flowId: _string(json['flowId'] ?? json['flow_id']),
      status: _string(json['status']),
    );
  }
}

/// One selectable action in a human approval gate.
class GateOption {
  const GateOption({this.actionId = '', this.label = ''});

  final String actionId;
  final String label;

  factory GateOption.fromJson(Map<String, dynamic> json) {
    return GateOption(
      actionId: _string(json['action_id'] ?? json['actionId']),
      label: _string(json['label']),
    );
  }
}

/// Payload of a `human_input_required` event.
class HumanGate {
  const HumanGate({
    required this.requestId,
    this.promptJson = '',
    this.allowedDecisions = const <String>[],
    this.options = const <GateOption>[],
    this.timeoutSeconds = 300,
    this.fallbackAction = '',
    this.pausedAt,
  });

  final String requestId;
  final String promptJson;
  final List<String> allowedDecisions;
  final List<GateOption> options;
  final int timeoutSeconds;
  final String fallbackAction;
  final DateTime? pausedAt;

  Map<String, dynamic>? get prompt {
    if (promptJson.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(promptJson);
      return _mapOrNull(decoded);
    } on FormatException {
      return null;
    }
  }

  /// Seconds left before the advertised gate timeout, never negative.
  int remainingSeconds(DateTime now) {
    final startedAt = pausedAt;
    if (startedAt == null) {
      return timeoutSeconds < 0 ? 0 : timeoutSeconds;
    }
    final remaining = startedAt
        .add(Duration(seconds: timeoutSeconds))
        .difference(now)
        .inSeconds;
    return remaining < 0 ? 0 : remaining;
  }

  factory HumanGate.fromJson(Map<String, dynamic> json) {
    final rawPrompt = json['prompt'];
    final promptJson = rawPrompt is String
        ? rawPrompt
        : rawPrompt == null
        ? ''
        : jsonEncode(rawPrompt);
    final allowed = json['allowed_decisions'];
    final options = json['options'];
    final pausedAtRaw = json['paused_at'];
    return HumanGate(
      requestId: _string(json['request_id'] ?? json['requestId']),
      promptJson: promptJson,
      allowedDecisions: <String>[
        if (allowed is List)
          for (final item in allowed)
            if (item != null) item.toString(),
      ],
      options: <GateOption>[
        if (options is List)
          for (final item in options)
            if (item is Map)
              GateOption.fromJson(
                item.map((key, value) => MapEntry(key.toString(), value)),
              ),
      ],
      timeoutSeconds: _int(json['timeout_seconds'], fallback: 300),
      fallbackAction: _string(json['fallback_action']),
      pausedAt: pausedAtRaw is String ? DateTime.tryParse(pausedAtRaw) : null,
    );
  }
}

/// Payload of an `output` event, parsed from its `content` JSON string.
class ReviewOutput {
  const ReviewOutput({
    this.action = '',
    this.confirmation = '',
    this.patientId = '',
    this.approvedAt = '',
    this.reviewerNote = '',
    this.rawContent = '',
  });

  final String action;
  final String confirmation;
  final String patientId;
  final String approvedAt;
  final String reviewerNote;
  final String rawContent;

  factory ReviewOutput.fromContent(String content) {
    try {
      final decoded = jsonDecode(content);
      final map = _mapOrNull(decoded);
      if (map != null) {
        return ReviewOutput(
          action: _string(map['action']),
          confirmation: _string(map['confirmation']),
          patientId: _string(map['patient_id']),
          approvedAt: _string(map['approved_at']),
          reviewerNote: _string(map['reviewer_note']),
          rawContent: content,
        );
      }
    } on FormatException {
      // Fall through to the raw-content shape.
    }
    return ReviewOutput(rawContent: content);
  }
}

String _string(Object? value) {
  if (value is String) {
    return value;
  }
  return value?.toString() ?? '';
}

int _int(Object? value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  if (value is String) {
    return int.tryParse(value) ?? fallback;
  }
  return fallback;
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
