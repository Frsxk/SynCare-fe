import '../core/api_exception.dart';
import 'patient.dart';
import 'checkin_record.dart';

sealed class QuestionOutcome {
  const QuestionOutcome();
  factory QuestionOutcome.fromJson(Object? value, String patientId) {
    final json = patientObject(value);
    bool exact(List<String> keys) =>
        json.keys.every(keys.contains) && keys.every(json.containsKey);
    switch (json['kind']) {
      case 'answer':
        if (!exact(['kind', 'text', 'citations', 'disclaimer'])) {
          throw const InvalidResponseException();
        }
        final text = patientText(json['text']),
            disclaimer = patientText(json['disclaimer']),
            raw = json['citations'];
        if (raw is! List ||
            raw.isEmpty ||
            raw.length > 100 ||
            !text.startsWith(disclaimer)) {
          throw const InvalidResponseException();
        }
        final citations = raw
            .map((v) => QuestionCitation.fromJson(v, patientId))
            .toList(growable: false);
        final blocks = RegExp(
          r'\[[^\[\]\r\n]+\]',
        ).allMatches(text).map((m) => m.group(0)).toList();
        if (blocks.length != citations.length) {
          throw const InvalidResponseException();
        }
        for (var i = 0; i < citations.length; i++) {
          if (blocks[i] != '[${citations[i].id} | ${citations[i].label}]') {
            throw const InvalidResponseException();
          }
        }
        return AskAnswer(
          text: text,
          rawText: text,
          citations: citations,
          disclaimer: disclaimer,
        );
      case 'refusal':
        if (!exact(['kind', 'text'])) throw const InvalidResponseException();
        return QuestionRefusal(patientText(json['text']));
      case 'emergency':
        if (!exact(['kind', 'reason', 'guidance'])) {
          throw const InvalidResponseException();
        }
        return QuestionEmergency(
          patientText(json['reason']),
          json['guidance'] == null
              ? null
              : EmergencyGuidance.fromJson(json['guidance']),
        );
      case 'error':
        if (!exact(['kind', 'code']) ||
            ![
              'retrieval_failed',
              'invalid_generated_selection',
              'invalid_flow_output',
            ].contains(json['code'])) {
          throw const InvalidResponseException();
        }
        return QuestionFailure(json['code'] as String);
      default:
        throw const InvalidResponseException();
    }
  }
}

class QuestionCitation {
  const QuestionCitation({
    required this.id,
    required this.label,
    required this.approved,
    required this.quote,
  });
  final String id, label, quote;
  final bool approved;
  factory QuestionCitation.fromJson(Object? value, String patientId) {
    final json = patientObject(value),
        id = patientText(json['id']),
        label = patientText(json['label']);
    if (json.keys.length != 4 ||
        !json.keys.every(['id', 'label', 'provenance', 'quote'].contains)) {
      throw const InvalidResponseException();
    }
    final approved = json['provenance'] == 'approved_plan';
    if (approved) {
      if (label != 'rencana_disetujui_workflow_sintetis' ||
          !id.startsWith('$patientId:') ||
          !RegExp(
            r'^(plan_text|instruction:\d+|medication:\d+|care_intensity:\d+)#[1-9]\d*$',
          ).hasMatch(id.substring(patientId.length + 1))) {
        throw const InvalidResponseException();
      }
    } else if (json['provenance'] != 'unapproved_education' ||
        label != 'draf_edukasi_tidak_disetujui' ||
        !RegExp(
          r'^(hf-aftercare|medication-safety):section:\d+#[1-9]\d*$',
        ).hasMatch(id)) {
      throw const InvalidResponseException();
    }
    return QuestionCitation(
      id: id,
      label: label,
      approved: approved,
      quote: patientText(json['quote']),
    );
  }
}

class QuestionRefusal extends QuestionOutcome {
  const QuestionRefusal(this.text);
  final String text;
}

class QuestionEmergency extends QuestionOutcome {
  const QuestionEmergency(this.reason, this.guidance);
  final String reason;
  final EmergencyGuidance? guidance;
}

class QuestionFailure extends QuestionOutcome {
  const QuestionFailure(this.code);
  final String code;
  String get message => switch (code) {
    'retrieval_failed' =>
      'Sumber jawaban belum dapat diambil. Coba lagi nanti.',
    _ => 'Jawaban belum tersedia. Silakan coba lagi.',
  };
}

class AskAnswer extends QuestionOutcome {
  const AskAnswer({
    required this.text,
    this.source,
    required this.rawText,
    this.citations = const [],
    this.disclaimer,
  });

  final String text;
  final String? source;
  final String rawText;
  final List<QuestionCitation> citations;
  final String? disclaimer;

  String get patientText {
    var displayed = text;
    for (var i = 0; i < citations.length; i++) {
      final citation = citations[i];
      displayed = displayed.replaceAll(
        '[${citation.id} | ${citation.label}]',
        '[${i + 1}]',
      );
    }
    return displayed;
  }

  // Legacy capture parser; authenticated Q1 always uses QuestionOutcome.fromJson.
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
