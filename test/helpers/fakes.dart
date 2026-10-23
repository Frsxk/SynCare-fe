import 'package:syncare_flutter/core/api_client.dart';
import 'package:syncare_flutter/core/config.dart';
import 'package:syncare_flutter/core/sse.dart';
import 'package:syncare_flutter/models/approved_plan.dart';
import 'package:syncare_flutter/models/ask_answer.dart';
import 'package:syncare_flutter/models/checkin_result.dart';
import 'package:syncare_flutter/models/discharge_result.dart';
import 'package:syncare_flutter/models/health.dart';
import 'package:syncare_flutter/models/plan_draft.dart';
import 'package:syncare_flutter/models/review_job.dart';

class FakeSyncareApi implements SyncareApi {
  Future<Health> Function()? onHealth;
  Future<DischargeResult> Function(String summary)? onDischarge;
  Future<CheckinResult> Function({
    required String patientId,
    required String message,
  })?
  onCheckin;
  Future<PlanDraft> Function({
    required String patientId,
    required String followupDate,
    required String hotline,
    required DischargeResult f1ScoredOutput,
  })?
  onDraftPlan;
  Future<ReviewJob> Function({required String draftJson})? onStartReview;
  Future<void> Function({
    required String jobId,
    required String requestId,
    required String actionId,
    required String actor,
    String reviewerNote,
  })?
  onResumeReview;
  Future<AskAnswer> Function({
    required String patientId,
    required String query,
  })?
  onAsk;
  Future<PlansResponse> Function()? onListPlans;
  Future<ApprovedPlanRecord> Function(String patientId)? onGetPlan;

  Never _unstubbed(String name) {
    throw UnimplementedError('FakeSyncareApi.$name is not stubbed');
  }

  @override
  Future<Health> health() {
    final handler = onHealth;
    if (handler == null) {
      _unstubbed('onHealth');
    }
    return handler();
  }

  @override
  Future<DischargeResult> discharge(String summary) {
    final handler = onDischarge;
    if (handler == null) {
      _unstubbed('onDischarge');
    }
    return handler(summary);
  }

  @override
  Future<CheckinResult> checkin({
    required String patientId,
    required String message,
  }) {
    final handler = onCheckin;
    if (handler == null) {
      _unstubbed('onCheckin');
    }
    return handler(patientId: patientId, message: message);
  }

  @override
  Future<PlanDraft> draftPlan({
    required String patientId,
    required String followupDate,
    required String hotline,
    required DischargeResult f1ScoredOutput,
  }) {
    final handler = onDraftPlan;
    if (handler == null) {
      _unstubbed('onDraftPlan');
    }
    return handler(
      patientId: patientId,
      followupDate: followupDate,
      hotline: hotline,
      f1ScoredOutput: f1ScoredOutput,
    );
  }

  @override
  Future<ReviewJob> startReview({required String draftJson}) {
    final handler = onStartReview;
    if (handler == null) {
      _unstubbed('onStartReview');
    }
    return handler(draftJson: draftJson);
  }

  @override
  Future<void> resumeReview({
    required String jobId,
    required String requestId,
    required String actionId,
    required String actor,
    String reviewerNote = '',
  }) {
    final handler = onResumeReview;
    if (handler == null) {
      _unstubbed('onResumeReview');
    }
    return handler(
      jobId: jobId,
      requestId: requestId,
      actionId: actionId,
      actor: actor,
      reviewerNote: reviewerNote,
    );
  }

  @override
  Future<AskAnswer> ask({required String patientId, required String query}) {
    final handler = onAsk;
    if (handler == null) {
      _unstubbed('onAsk');
    }
    return handler(patientId: patientId, query: query);
  }

  @override
  Future<PlansResponse> listPlans() {
    final handler = onListPlans;
    if (handler == null) {
      _unstubbed('onListPlans');
    }
    return handler();
  }

  @override
  Future<ApprovedPlanRecord> getPlan(String patientId) {
    final handler = onGetPlan;
    if (handler == null) {
      _unstubbed('onGetPlan');
    }
    return handler(patientId);
  }
}

class FakeReviewEventSource implements ReviewEventSource {
  FakeReviewEventSource({this.onEvents});

  Stream<SseEvent> Function(String jobId)? onEvents;

  @override
  Stream<SseEvent> events(String jobId) {
    final handler = onEvents;
    if (handler == null) {
      throw UnimplementedError('FakeReviewEventSource.onEvents is not stubbed');
    }
    return handler(jobId);
  }
}

class FakeTokenSource implements TokenSource {
  FakeTokenSource([this.token]);

  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String token) async {
    this.token = token;
  }

  @override
  Future<void> clear() async {
    token = null;
  }
}
