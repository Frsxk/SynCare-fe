/// Presentation-only helpers for the patient `Rencana tindak lanjut` view.
///
/// The API stores an approved plan as a narrative string plus FHIR-shaped
/// arrays. These helpers choose display units and remove list syntax only; they
/// never rewrite clinical words, doses, dates or resource data. Stringifying a
/// map-shaped resource is deliberately unsupported.
library;

import '../../models/approved_plan.dart';

final RegExp _lineBreak = RegExp(r'\r\n|\r|\n');
final RegExp _inlineBullet = RegExp(r'\s*[•·◦▪▫‣]\s+');
final RegExp _bulletPrefix = RegExp(r'^[•·◦▪▫‣]\s*');
final RegExp _dashPrefix = RegExp(r'^(?:-|–|—)\s+');
final RegExp _numberedPrefix = RegExp(r'^(?:\(\d{1,2}\)|\d{1,2}[.)])\s+');
final RegExp _sentenceBoundary = RegExp(r'(?<=[.!?])\s+(?=[A-Z])');
final RegExp _inventoryCue = RegExp(
  r'(?:daftar obat|obat|medikasi|medication|resep|dosis)',
  caseSensitive: false,
);
final RegExp _doseCue = RegExp(
  r'(?:mg\b|mcg\b|ml\b|tablet|kapsul|sirup|tetes|'
  r'\b\d+\s?[x×]\s?\d+\b|\d+[.,]\d+)',
  caseSensitive: false,
);

/// Splits the approved plan narrative into patient-readable display items.
///
/// Newlines, real bullets and numbered bullets are structural delimiters.
/// Semicolons become item boundaries only when the sentence is not a clinical
/// inventory: medication lists such as `furosemide 40mg 2x1; bisoprolol
/// 2.5mg 1x1` stay intact. Decimals are never split because sentence
/// boundaries require whitespace after the punctuation.
List<String> planTextItems(String value) {
  final String text = value
      .replaceAll(_lineBreak, '\n')
      .replaceAll(_inlineBullet, '\n• ')
      .trim();
  if (text.isEmpty) {
    return const <String>[];
  }
  final List<String> lines = text
      .split('\n')
      .where((String line) => line.trim().isNotEmpty)
      .toList(growable: false);
  if (lines.length > 1) {
    return <String>[
      for (final String line in lines) ..._splitUnits(_stripMarker(line)),
    ];
  }
  return _splitUnits(_stripMarker(text));
}

/// Returns the structured plan list from the approved-plan schema.
///
/// `satuseshat.careplan.activity` is the canonical ordered array. Only string
/// entries are accepted; map-shaped entries are skipped rather than converted
/// with `toString()`. `care_intensity` is the compatible fallback.
List<String> planStructuredItems(ApprovedPlan plan) {
  final Object? carePlan = plan.satuseshat['careplan'];
  if (carePlan is Map) {
    final Object? activity = carePlan['activity'];
    if (activity is List) {
      final List<String> items = _listItems(activity.whereType<Object?>());
      if (items.isNotEmpty) {
        return items;
      }
    }
  }
  return _listItems(plan.careIntensity);
}

List<String> _listItems(Iterable<Object?> values) {
  return <String>[
    for (final Object? value in values)
      if (value is String) ...planTextItems(value),
  ];
}

bool _protectedClinicalList(String sentence) {
  final int colon = sentence.indexOf(':');
  if (colon > 0 &&
      _inventoryCue.hasMatch(sentence.substring(0, colon))) {
    return true;
  }
  final List<String> parts = sentence.split(';');
  return parts.length > 1 &&
      parts.any((String part) => _doseCue.hasMatch(part));
}

List<String> _splitUnits(String value) {
  final List<String> items = <String>[];
  for (final String sentence in value.split(_sentenceBoundary)) {
    final String clean = sentence.trim();
    if (clean.isEmpty) {
      continue;
    }
    if (_protectedClinicalList(clean)) {
      items.add(clean);
      continue;
    }
    final List<String> parts = clean
        .split(';')
        .map((String part) => part.trim())
        .where((String part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.length > 1) {
      items.addAll(parts);
    } else {
      items.add(clean);
    }
  }
  return items;
}

String _stripMarker(String value) {
  String text = value.trim();
  for (final RegExp pattern in <RegExp>[
    _bulletPrefix,
    _dashPrefix,
    _numberedPrefix,
  ]) {
    final RegExpMatch? match = pattern.firstMatch(text);
    if (match != null) {
      text = text.substring(match.end).trimLeft();
    }
  }
  return text;
}
