/// Parsed F5 answer. [rawText] is the server output unchanged; [text] keeps the
/// answer verbatim with the trailing provenance block removed, and [source]
/// holds that provenance.
class AskAnswer {
  const AskAnswer({required this.text, this.source, required this.rawText});

  final String text;
  final String? source;
  final String rawText;

  factory AskAnswer.fromText(String rawText) {
    final match = _trailingProvenance.firstMatch(rawText);
    final source = match?.group(1)?.trim();
    final stripped = match == null
        ? rawText
        : rawText.substring(0, match.start).trimRight();
    return AskAnswer(
      text: stripped.isEmpty ? rawText : stripped,
      source: (source == null || source.isEmpty) ? null : source,
      rawText: rawText,
    );
  }
}

final RegExp _trailingProvenance = RegExp(r'\[([^\[\]]*)\]\s*$');
