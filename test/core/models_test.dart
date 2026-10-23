import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:syncare_flutter/core/api_exception.dart';
import 'package:syncare_flutter/models/approved_plan.dart';
import 'package:syncare_flutter/models/ask_answer.dart';
import 'package:syncare_flutter/models/checkin_result.dart';
import 'package:syncare_flutter/models/discharge_result.dart';
import 'package:syncare_flutter/models/health.dart';
import 'package:syncare_flutter/models/plan_draft.dart';
import 'package:syncare_flutter/models/review_job.dart';

final Map<String, dynamic> _f1Json = <String, dynamic>{
  'episode': <String, dynamic>{
    'diagnosis': 'CHF NYHA III',
    'medications': <String>['furosemide 40mg harian'],
    'instructions': <String>['Timbang BB harian'],
    'followup_needs': <String>['Kontrol poli jantung'],
    'length_of_stay_days': 6,
    'admission_type': 'emergency',
    'comorbidity_count': 4,
    'admissions_prior_12m': 3,
  },
  'score': 4,
  'tier': 'HIGH',
  'risk_factors': <String, dynamic>{
    'length_of_stay_days': <String, dynamic>{
      'value': 6,
      'threshold': 5,
      'points': 2,
      'met': true,
    },
    'admission_type': <String, dynamic>{
      'value': 'emergency',
      'threshold': 'emergency',
      'points': 1,
      'met': true,
    },
    'comorbidity_count': <String, dynamic>{
      'value': 4,
      'threshold': 3,
      'points': 1,
      'met': true,
    },
  },
  'rationale': 'LOS 6 hari dan komorbiditas tinggi.',
  'label': 'demo-heuristic-v1',
  'missing_fields': <String>[],
  'not_clinically_validated': true,
  'synthetic_demo_only': true,
  'disclaimer': 'Demo sintetis, bukan nasihat klinis.',
};

final Map<String, dynamic> _f3Json = <String, dynamic>{
  'plan_text': 'Pemantauan ketat selama 7 hari.',
  'satuseshat': <String, dynamic>{
    'careplan': <String, dynamic>{'resourceType': 'CarePlan'},
    'servicerequest': <String, dynamic>{'resourceType': 'ServiceRequest'},
    'task': <String, dynamic>{'resourceType': 'Task'},
  },
  'patient_id': 'demo-1',
  'tier': 'HIGH',
  'care_intensity': <String>['Telepon 48 jam', 'Kunjungan 7 hari'],
  'status': 'DRAFT pending human approval',
  'label': 'demo-heuristic-v1',
  'missing_facts': <String>[],
  'disclaimer': 'Demo sintetis.',
  'source_input': 'f1_scored_output',
};

void main() {
  group('Health', () {
    test('parses the live shape', () {
      final health = Health.fromJson(<String, dynamic>{
        'status': 'ok',
        'langflow': 'reachable',
        'reviewDbPresent': true,
        'flowCount': 5,
        'manifestComplete': true,
        'missingFlows': <String>[],
        'readOnly': false,
        'disclaimer': 'Demo sintetis.',
      });

      expect(health.status, 'ok');
      expect(health.langflow, 'reachable');
      expect(health.langflowReachable, isTrue);
      expect(health.reviewDbPresent, isTrue);
      expect(health.flowCount, 5);
      expect(health.manifestComplete, isTrue);
      expect(health.missingFlows, isEmpty);
      expect(health.readOnly, isFalse);
      expect(health.disclaimer, 'Demo sintetis.');
    });

    test('reports an unreachable langflow and tolerates nulls', () {
      final health = Health.fromJson(<String, dynamic>{
        'langflow': 'unreachable',
      });

      expect(health.langflowReachable, isFalse);
      expect(health.status, '');
      expect(health.flowCount, 0);
    });
  });

  group('DischargeResult', () {
    test('parses the live F1 shape', () {
      final result = DischargeResult.fromJson(_f1Json);

      expect(result.episode.diagnosis, 'CHF NYHA III');
      expect(result.episode.medications, <String>['furosemide 40mg harian']);
      expect(result.episode.lengthOfStayDays, 6);
      expect(result.episode.admissionType, 'emergency');
      expect(result.episode.comorbidityCount, 4);
      expect(result.episode.admissionsPrior12m, 3);
      expect(result.score, 4);
      expect(result.tier, 'HIGH');
      expect(result.riskFactors, hasLength(3));
      final los = result.riskFactors['length_of_stay_days']!;
      expect(los.name, 'length_of_stay_days');
      expect(los.value, 6);
      expect(los.threshold, 5);
      expect(los.points, 2);
      expect(los.met, isTrue);
      expect(result.notClinicallyValidated, isTrue);
      expect(result.syntheticDemoOnly, isTrue);
      expect(result.rawJson['label'], 'demo-heuristic-v1');
    });

    test('toF1ScoredOutput keeps snake_case values verbatim', () {
      final result = DischargeResult.fromJson(_f1Json);
      final scored = result.toF1ScoredOutput();

      expect(scored.keys.toSet(), <String>{
        'episode',
        'score',
        'tier',
        'risk_factors',
        'rationale',
        'label',
      });
      expect(scored['episode'], equals(_f1Json['episode']));
      expect(scored['score'], 4);
      expect(scored['tier'], 'HIGH');
      expect(scored['risk_factors'], equals(_f1Json['risk_factors']));
      expect(scored['rationale'], _f1Json['rationale']);
      expect(scored['label'], 'demo-heuristic-v1');
    });
  });

  group('CheckinResult', () {
    test('parses the escalation branch', () {
      final result = CheckinResult.fromJson(<String, dynamic>{
        'action': 'escalate_immediately',
        'reason': 'sesak napas berat, nyeri dada',
      });

      expect(result.isEscalation, isTrue);
      expect(result.reason, 'sesak napas berat, nyeri dada');
      expect(result.adjustments, isEmpty);
    });

    test('parses the routine branch with adjustments', () {
      final result = CheckinResult.fromJson(<String, dynamic>{
        'patient_id': 'demo-1',
        'baseline_score': 3,
        'baseline_tier': 'MEDIUM',
        'adjustments': <Map<String, dynamic>>[
          <String, dynamic>{
            'condition': 'sesak_memburuk',
            'applied': true,
            'points': 2,
          },
          <String, dynamic>{
            'condition': 'demam',
            'applied': false,
            'points': 0,
          },
        ],
        'score': 5,
        'tier': 'HIGH',
        'tier_changed': true,
        'action': 'continue_monitoring',
        'next_checkin_days': 2,
        'label': 'demo-heuristic-v1',
        'disclaimer': 'Demo sintetis.',
      });

      expect(result.isEscalation, isFalse);
      expect(result.patientId, 'demo-1');
      expect(result.baselineScore, 3);
      expect(result.baselineTier, 'MEDIUM');
      expect(result.adjustments, hasLength(2));
      expect(result.adjustments.first.condition, 'sesak_memburuk');
      expect(result.adjustments.first.applied, isTrue);
      expect(result.adjustments.first.points, 2);
      expect(result.adjustments.last.applied, isFalse);
      expect(result.score, 5);
      expect(result.tier, 'HIGH');
      expect(result.isTierChange, isTrue);
      expect(result.nextCheckinDays, 2);
    });

    test('isTierChange follows the server tier_changed flag', () {
      final result = CheckinResult.fromJson(<String, dynamic>{
        'baseline_tier': 'HIGH',
        'tier': 'HIGH',
        'tier_changed': false,
      });

      expect(result.isTierChange, isFalse);
    });
  });

  group('PlanDraft', () {
    test('parses care_intensity as a list', () {
      final draft = PlanDraft.fromJson(_f3Json);

      expect(draft.planText, 'Pemantauan ketat selama 7 hari.');
      expect(draft.patientId, 'demo-1');
      expect(draft.tier, 'HIGH');
      expect(draft.careIntensity, <String>[
        'Telepon 48 jam',
        'Kunjungan 7 hari',
      ]);
      expect(
        draft.satuseshat.keys,
        containsAll(<String>['careplan', 'servicerequest', 'task']),
      );
      expect(draft.status, 'DRAFT pending human approval');
      expect(draft.toJson()['care_intensity'], isA<List<String>>());
      expect(draft.toJson()['plan_text'], draft.planText);
    });

    test('accepts care_intensity as a comma-separated string', () {
      final draft = PlanDraft.fromJson(<String, dynamic>{
        ..._f3Json,
        'care_intensity': 'Telepon 48 jam, Kunjungan 7 hari',
      });

      expect(draft.careIntensity, <String>[
        'Telepon 48 jam',
        'Kunjungan 7 hari',
      ]);
    });

    test('accepts a single string care_intensity', () {
      final draft = PlanDraft.fromJson(<String, dynamic>{
        ..._f3Json,
        'care_intensity': 'Telepon 48 jam',
      });

      expect(draft.careIntensity, <String>['Telepon 48 jam']);
    });

    test('tolerates an absent care_intensity', () {
      final draft = PlanDraft.fromJson(<String, dynamic>{
        ..._f3Json,
        'care_intensity': null,
      });

      expect(draft.careIntensity, isEmpty);
    });
  });

  group('Approved plans', () {
    final Map<String, dynamic> plansJson = <String, dynamic>{
      'plans': <Map<String, dynamic>>[
        <String, dynamic>{
          'patientId': 'chf-chain-164858',
          'plan_json': jsonEncode(_f3Json),
          'approved_at': '2026-10-09T16:49:13.798724+00:00',
          'reviewer_note': 'Disetujui.',
        },
      ],
      'audit': <Map<String, dynamic>>[
        <String, dynamic>{
          'action': 'Approve',
          'actor': 'frisky',
          'timestamp': '2026-10-09T16:49:13.798724+00:00',
        },
      ],
    };

    test('parses plan_json strings', () {
      final response = PlansResponse.fromJson(plansJson);

      expect(response.plans, hasLength(1));
      final record = response.plans.single;
      expect(record.patientId, 'chf-chain-164858');
      expect(record.planJsonString, jsonEncode(_f3Json));
      expect(record.plan.planText, 'Pemantauan ketat selama 7 hari.');
      expect(record.plan.tier, 'HIGH');
      expect(record.plan.status, 'DRAFT pending human approval');
      expect(record.plan.careIntensity, hasLength(2));
      expect(record.approvedAt.toUtc().year, 2026);
      expect(record.reviewerNote, 'Disetujui.');

      expect(response.audit, hasLength(1));
      expect(response.audit.single.action, 'Approve');
      expect(response.audit.single.actor, 'frisky');
      expect(response.audit.single.timestamp.toUtc().month, 10);
    });

    test('throws InvalidResponseException for malformed plan_json', () {
      expect(
        () => ApprovedPlanRecord.fromJson(<String, dynamic>{
          'patientId': 'demo-1',
          'plan_json': '{not valid json',
          'approved_at': '2026-10-09T16:49:13.798724+00:00',
        }),
        throwsA(isA<InvalidResponseException>()),
      );
    });

    test('throws InvalidResponseException when plan_json is absent', () {
      expect(
        () => ApprovedPlanRecord.fromJson(<String, dynamic>{
          'patientId': 'demo-1',
          'approved_at': '2026-10-09T16:49:13.798724+00:00',
        }),
        throwsA(isA<InvalidResponseException>()),
      );
    });
  });

  group('Review models', () {
    test('parses the job handle', () {
      final job = ReviewJob.fromJson(<String, dynamic>{
        'jobId': 'job-1',
        'flowId': 'flow-1',
        'status': 'pending',
      });

      expect(job.jobId, 'job-1');
      expect(job.flowId, 'flow-1');
      expect(job.status, 'pending');
    });

    test('parses a human gate payload', () {
      final gate = HumanGate.fromJson(<String, dynamic>{
        'request_id': 'req-1',
        'kind': 'human_input_required',
        'prompt': '{"question":"Setujui rencana?"}',
        'options': <Map<String, dynamic>>[
          <String, dynamic>{'action_id': 'approve', 'label': 'Approve'},
          <String, dynamic>{
            'action_id': 'request_changes',
            'label': 'Request Changes',
          },
          <String, dynamic>{'action_id': 'escalate', 'label': 'Escalate'},
        ],
        'allowed_decisions': <String>[
          'approve',
          'request_changes',
          'escalate',
          'fallback',
        ],
        'timeout_seconds': 300,
        'fallback_action': 'fallback',
        'paused_at': '2026-10-23T10:00:00Z',
      });

      expect(gate.requestId, 'req-1');
      expect(gate.prompt, <String, dynamic>{'question': 'Setujui rencana?'});
      expect(gate.options, hasLength(3));
      expect(gate.options.first.actionId, 'approve');
      expect(gate.options[1].label, 'Request Changes');
      expect(gate.allowedDecisions, hasLength(4));
      expect(gate.timeoutSeconds, 300);
      expect(gate.fallbackAction, 'fallback');
      expect(
        gate.remainingSeconds(DateTime.parse('2026-10-23T10:02:00Z')),
        180,
      );
      expect(gate.remainingSeconds(DateTime.parse('2026-10-23T11:00:00Z')), 0);
    });

    test('defaults gate timeout and reports it as remaining when unpaused', () {
      final gate = HumanGate.fromJson(<String, dynamic>{'request_id': 'req-2'});

      expect(gate.timeoutSeconds, 300);
      expect(gate.remainingSeconds(DateTime.utc(2026, 10, 23)), 300);
      expect(gate.pausedAt, isNull);
      expect(gate.prompt, isNull);
    });

    test('parses review output content', () {
      final output = ReviewOutput.fromContent(
        '{"action":"approve","confirmation":"disetujui","patient_id":"demo-1",'
        '"approved_at":"2026-10-23T10:00:00Z","reviewer_note":"ok"}',
      );

      expect(output.action, 'approve');
      expect(output.confirmation, 'disetujui');
      expect(output.patientId, 'demo-1');
      expect(output.approvedAt, '2026-10-23T10:00:00Z');
      expect(output.reviewerNote, 'ok');
      expect(output.rawContent, contains('"action":"approve"'));
    });

    test('keeps unparseable review content raw', () {
      final output = ReviewOutput.fromContent('bukan json');

      expect(output.action, '');
      expect(output.rawContent, 'bukan json');
    });
  });

  group('AskAnswer', () {
    test('extracts trailing provenance and keeps the answer verbatim', () {
      const raw =
          'Boleh, tapi ukur tensi setiap pagi. '
          '[patient:care_intensity:1#1 | approved_plan:chf-chain-164858]';

      final answer = AskAnswer.fromText(raw);

      expect(answer.text, 'Boleh, tapi ukur tensi setiap pagi.');
      expect(
        answer.source,
        'patient:care_intensity:1#1 | approved_plan:chf-chain-164858',
      );
      expect(answer.rawText, raw);
    });

    test('leaves answers without provenance untouched', () {
      const raw = 'Tidak ada rencana yang disetujui.';

      final answer = AskAnswer.fromText(raw);

      expect(answer.text, raw);
      expect(answer.source, isNull);
      expect(answer.rawText, raw);
    });
  });
}
