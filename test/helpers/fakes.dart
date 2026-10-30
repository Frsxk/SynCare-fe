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
import 'package:syncare_flutter/models/patient.dart';
import 'package:syncare_flutter/models/checkin_record.dart';
import 'package:syncare_flutter/models/homecare.dart';
import 'package:syncare_flutter/models/escalation.dart';
import 'package:syncare_flutter/models/verified_care_plan.dart';

class FakeSyncareApi implements SyncareApi {
  Future<VerifiedPlanPage> Function(String patientId, String? cursor)?
  onListVerifiedPlans;
  @override
  Future<VerifiedPlanPage> listVerifiedPlans(
    String patientId, {
    String? cursor,
  }) =>
      onListVerifiedPlans?.call(patientId, cursor) ??
      Future.error(UnimplementedError('listVerifiedPlans'));
  Future<EscalationPage> Function(String patientId, String? cursor)?
  onListEscalations;
  Future<Escalation> Function(String alertId, String? cursor)? onGetEscalation;
  Future<EmergencyRequestResult> Function(
    String patientId,
    String reason,
    String key,
  )?
  onRequestEmergency;
  @override
  Future<EscalationPage> listEscalations(String patientId, {String? cursor}) =>
      onListEscalations?.call(patientId, cursor) ??
      Future.error(UnimplementedError('listEscalations'));
  @override
  Future<Escalation> getEscalation(String alertId, {String? cursor}) =>
      onGetEscalation?.call(alertId, cursor) ??
      Future.error(UnimplementedError('getEscalation'));
  @override
  Future<EmergencyRequestResult> requestEmergency({
    required String patientId,
    required String reason,
    required String requestKey,
  }) =>
      onRequestEmergency?.call(patientId, reason, requestKey) ??
      Future.error(UnimplementedError('requestEmergency'));
  Future<BookingPage> Function(String patientId, String? cursor)?
  onListBookings;
  Future<Booking> Function(String bookingId)? onGetBooking;
  Future<Booking> Function(
    String bookingId,
    int expectedVersion,
    String reason,
    String key,
  )?
  onCancelBooking;
  @override
  Future<BookingPage> listBookings(String patientId, {String? cursor}) =>
      onListBookings?.call(patientId, cursor) ??
      Future.error(UnimplementedError('listBookings'));
  @override
  Future<Booking> getBooking(String bookingId) =>
      onGetBooking?.call(bookingId) ??
      Future.error(UnimplementedError('getBooking'));
  @override
  Future<Booking> cancelBooking({
    required String bookingId,
    required int expectedVersion,
    required String reason,
    required String requestKey,
  }) =>
      onCancelBooking?.call(bookingId, expectedVersion, reason, requestKey) ??
      Future.error(UnimplementedError('cancelBooking'));
  Future<ServicePage> Function(String? cursor)? onHomecareServices;
  Future<Booking> Function(String patientId, BookingInput input, String key)?
  onRequestBooking;
  @override
  Future<ServicePage> listHomecareServices({String? cursor}) =>
      onHomecareServices?.call(cursor) ??
      Future.error(UnimplementedError('homecare'));
  @override
  Future<Booking> requestBooking({
    required String patientId,
    required BookingInput input,
    required String requestKey,
  }) =>
      onRequestBooking?.call(patientId, input, requestKey) ??
      Future.error(UnimplementedError('booking'));
  Future<CheckinRecord> Function(
    String patientId,
    String message,
    String requestKey,
  )?
  onSubmitCheckin;
  Future<CheckinRecord> Function(String id)? onGetCheckin;
  Future<CheckinPage> Function(String patientId, String? cursor)?
  onListCheckins;
  Future<EmergencyGuidance> Function()? onGuidance;
  @override
  Future<CheckinRecord> submitCheckin({
    required String patientId,
    required String message,
    required String requestKey,
  }) =>
      onSubmitCheckin?.call(patientId, message, requestKey) ??
      Future.error(UnimplementedError('submitCheckin'));
  @override
  Future<CheckinRecord> getCheckin(String checkinId) =>
      onGetCheckin?.call(checkinId) ??
      Future.error(UnimplementedError('getCheckin'));
  @override
  Future<CheckinPage> listCheckins(String patientId, {String? cursor}) =>
      onListCheckins?.call(patientId, cursor) ??
      Future.error(UnimplementedError('listCheckins'));
  @override
  Future<EmergencyGuidance> getEmergencyGuidance() =>
      onGuidance?.call() ?? Future.error(UnimplementedError('guidance'));
  Future<PatientOverview> Function(String patientId)? onGetPatientOverview;
  @override
  Future<PatientOverview> getPatientOverview(String patientId) =>
      onGetPatientOverview?.call(patientId) ??
      Future.error(UnimplementedError('onGetPatientOverview'));
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
  Future<QuestionOutcome> Function({
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
  Future<QuestionOutcome> ask({
    required String patientId,
    required String query,
  }) {
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
