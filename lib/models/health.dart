/// Response of `GET /api/health`.
class Health {
  const Health({
    this.status = '',
    this.langflow = '',
    this.reviewDbPresent = false,
    this.flowCount = 0,
    this.manifestComplete = false,
    this.missingFlows = const <String>[],
    this.readOnly = false,
    this.disclaimer = '',
  });

  final String status;
  final String langflow;
  final bool reviewDbPresent;
  final int flowCount;
  final bool manifestComplete;
  final List<String> missingFlows;
  final bool readOnly;
  final String disclaimer;

  bool get langflowReachable => langflow.toLowerCase() == 'reachable';

  factory Health.fromJson(Map<String, dynamic> json) {
    return Health(
      status: _string(json['status']),
      langflow: _string(json['langflow']),
      reviewDbPresent: _bool(json['reviewDbPresent']),
      flowCount: _int(json['flowCount']),
      manifestComplete: _bool(json['manifestComplete']),
      missingFlows: _stringList(json['missingFlows']),
      readOnly: _bool(json['readOnly']),
      disclaimer: _string(json['disclaimer']),
    );
  }
}

String _string(Object? value) {
  if (value is String) {
    return value;
  }
  return value?.toString() ?? '';
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
