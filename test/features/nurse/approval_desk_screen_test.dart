import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncare_flutter/core/api_exception.dart';
import 'package:syncare_flutter/core/config.dart';
import 'package:syncare_flutter/core/providers.dart';
import 'package:syncare_flutter/core/sse.dart';
import 'package:syncare_flutter/features/nurse/approval_desk_screen.dart';
import 'package:syncare_flutter/models/health.dart';
import 'package:syncare_flutter/models/plan_draft.dart';
import 'package:syncare_flutter/models/review_job.dart';
import 'package:syncare_flutter/widgets/disclaimer_banner.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

const String _planText =
    'Kontrol ulang dalam 7 hari di puskesmas terdekat. Pantau tekanan darah '
    'setiap pagi dan hubungi hotline bila muncul sesak napas.';

final PlanDraft _draft = PlanDraft(
  planText: _planText,
  patientId: 'demo-1',
  tier: 'MEDIUM',
  status: 'DRAFT pending human approval',
  rawJson: <String, dynamic>{
    'plan_text': _planText,
    'patient_id': 'demo-1',
    'tier': 'MEDIUM',
    'status': 'DRAFT pending human approval',
  },
);

const String _requestId = 'HumanInput-IvOz5:job-1';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Widget screen(
    FakeSyncareApi api, {
    PlanDraft? draft,
    FakeReviewEventSource? events,
  }) {
    return wrapScreen(
      const NurseApprovalDeskScreen(),
      overrides: <Override>[
        apiProvider.overrideWithValue(api),
        draftResultProvider.overrideWith((ref) => draft),
        if (events != null) reviewEventsProvider.overrideWithValue(events),
      ],
    );
  }

  FakeReviewEventSource eventsFor(Stream<SseEvent> stream) {
    return FakeReviewEventSource(onEvents: (_) => stream);
  }

  FakeSyncareApi startApi({String jobId = 'job-1'}) {
    final FakeSyncareApi api = FakeSyncareApi();
    api.onStartReview = ({required String draftJson}) async {
      return ReviewJob(jobId: jobId, flowId: 'flow-1', status: 'started');
    };
    return api;
  }

  Map<String, dynamic> gateData({
    String requestId = _requestId,
    DateTime? pausedAt,
    int timeoutSeconds = 300,
    String fallbackAction = 'fallback',
  }) {
    return <String, dynamic>{
      'request_id': requestId,
      'prompt': jsonEncode(<String, dynamic>{'plan_text': _planText}),
      'options': <Map<String, String>>[
        <String, String>{'action_id': 'approve', 'label': 'Setujui'},
        <String, String>{
          'action_id': 'request_changes',
          'label': 'Minta Perubahan',
        },
        <String, String>{'action_id': 'escalate', 'label': 'Eskalasi'},
      ],
      'allowed_decisions': <String>[
        'approve',
        'request_changes',
        'escalate',
        'fallback',
      ],
      'timeout_seconds': timeoutSeconds,
      'fallback_action': fallbackAction,
      'paused_at': (pausedAt ?? DateTime.now()).toIso8601String(),
    };
  }

  Future<void> tapStart(WidgetTester tester) async {
    final Finder button = find.text('Kirim ke meja persetujuan');
    await tester.ensureVisible(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pump();
    await tester.pump();
  }

  Future<void> emit(
    WidgetTester tester,
    StreamController<SseEvent> controller,
    String eventName,
    Map<String, dynamic> data,
  ) async {
    controller.add(
      SseEvent(
        event: null,
        data: jsonEncode(<String, dynamic>{'event': eventName, 'data': data}),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> emitGate(
    WidgetTester tester,
    StreamController<SseEvent> controller, {
    Map<String, dynamic>? data,
  }) {
    return emit(tester, controller, 'human_input_required', data ?? gateData());
  }

  Future<void> disposeScreen(
    WidgetTester tester, [
    StreamController<SseEvent>? controller,
  ]) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    if (controller != null) {
      await controller.close();
    }
  }

  testWidgets('empty draft shows the empty state and draft shortcut', (
    tester,
  ) async {
    await tester.pumpWidget(screen(FakeSyncareApi()));

    expect(find.byType(DisclaimerBanner), findsOneWidget);
    expect(find.text('Belum ada draf'), findsOneWidget);
    expect(find.text('Ke draf'), findsOneWidget);
    expect(find.text('Kirim ke meja persetujuan'), findsNothing);

    await disposeScreen(tester);
  });

  testWidgets('idle state renders the draft, reviewer, and disclaimer', (
    tester,
  ) async {
    await tester.pumpWidget(screen(FakeSyncareApi(), draft: _draft));

    expect(find.byType(DisclaimerBanner), findsOneWidget);
    expect(find.text('Draf rencana'), findsOneWidget);
    expect(find.textContaining('Kontrol ulang dalam 7 hari'), findsOneWidget);
    expect(find.text('ID pasien: demo-1'), findsOneWidget);
    expect(find.text(AppConfig.defaultReviewer), findsOneWidget);
    expect(find.text('Kirim ke meja persetujuan'), findsOneWidget);

    await disposeScreen(tester);
  });

  testWidgets(
    'starting state shows progress while the review request is open',
    (tester) async {
      final Completer<ReviewJob> completer = Completer<ReviewJob>();
      final FakeSyncareApi api = FakeSyncareApi();
      api.onStartReview = ({required String draftJson}) => completer.future;
      final StreamController<SseEvent> controller =
          StreamController<SseEvent>.broadcast();

      await tester.pumpWidget(
        screen(api, draft: _draft, events: eventsFor(controller.stream)),
      );
      await tapStart(tester);

      expect(find.text('Memulai aliran persetujuan…'), findsOneWidget);

      completer.complete(const ReviewJob(jobId: 'job-1'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Menunggu persetujuan'), findsOneWidget);
      expect(find.byType(DisclaimerBanner), findsOneWidget);

      await disposeScreen(tester, controller);
    },
  );

  testWidgets('start sends the raw draft JSON and enters waiting', (
    tester,
  ) async {
    String? sentDraft;
    final FakeSyncareApi api = FakeSyncareApi();
    api.onStartReview = ({required String draftJson}) async {
      sentDraft = draftJson;
      return const ReviewJob(jobId: 'job-1', flowId: 'flow-1');
    };
    final StreamController<SseEvent> controller =
        StreamController<SseEvent>.broadcast();

    await tester.pumpWidget(
      screen(api, draft: _draft, events: eventsFor(controller.stream)),
    );
    await tapStart(tester);

    expect(find.text('Menunggu persetujuan'), findsOneWidget);
    expect(find.textContaining('job-1'), findsOneWidget);
    expect(find.textContaining('Waktu berjalan:'), findsOneWidget);
    expect(find.byType(DisclaimerBanner), findsOneWidget);
    expect(jsonDecode(sentDraft!), _draft.rawJson);

    await disposeScreen(tester, controller);
  });

  testWidgets('gate event shows the request id and four decision buttons', (
    tester,
  ) async {
    final FakeSyncareApi api = startApi();
    final StreamController<SseEvent> controller =
        StreamController<SseEvent>.broadcast();

    await tester.pumpWidget(
      screen(api, draft: _draft, events: eventsFor(controller.stream)),
    );
    await tapStart(tester);
    await emitGate(tester, controller);

    expect(find.text('Persetujuan manusia diperlukan'), findsOneWidget);
    expect(find.text(_requestId), findsOneWidget);
    expect(find.textContaining('Sisa waktu:'), findsOneWidget);
    expect(find.text('Setujui'), findsOneWidget);
    expect(find.text('Minta Perubahan'), findsOneWidget);
    expect(find.text('Eskalasi'), findsOneWidget);
    expect(find.text('Fallback'), findsOneWidget);
    expect(find.textContaining('tindakan serius'), findsOneWidget);

    await disposeScreen(tester, controller);
  });

  testWidgets('approve resumes with the mandatory request id and typed args', (
    tester,
  ) async {
    final FakeSyncareApi api = startApi();
    final Map<String, Object?> captured = <String, Object?>{};
    api.onResumeReview =
        ({
          required String jobId,
          required String requestId,
          required String actionId,
          required String actor,
          String reviewerNote = '',
        }) async {
          captured
            ..['jobId'] = jobId
            ..['requestId'] = requestId
            ..['actionId'] = actionId
            ..['actor'] = actor
            ..['reviewerNote'] = reviewerNote;
        };

    final StreamController<SseEvent> controller =
        StreamController<SseEvent>.broadcast();
    await tester.pumpWidget(
      screen(api, draft: _draft, events: eventsFor(controller.stream)),
    );
    await tapStart(tester);
    await emitGate(tester, controller);

    final Finder reviewerField = find.byType(TextField).at(0);
    final Finder noteField = find.byType(TextField).at(1);
    await tester.ensureVisible(reviewerField);
    await tester.pump();
    await tester.enterText(reviewerField, 'perawat-uji');
    await tester.enterText(noteField, 'Setuju, kontrol 7 hari.');
    await tester.pump();

    final Finder approve = find.text('Setujui');
    await tester.ensureVisible(approve);
    await tester.pump();
    await tester.tap(approve);
    await tester.pump();
    await tester.pump();

    expect(captured['jobId'], 'job-1');
    expect(captured['requestId'], _requestId);
    expect(captured['actionId'], 'approve');
    expect(captured['actor'], 'perawat-uji');
    expect(captured['reviewerNote'], 'Setuju, kontrol 7 hari.');
    expect(captured.containsKey('decision'), isFalse);
    expect(find.text('Keputusan terkirim. Menunggu hasil…'), findsOneWidget);

    await disposeScreen(tester, controller);
  });

  testWidgets('a failed resume keeps the gate and retries the same request id', (
    tester,
  ) async {
    final FakeSyncareApi api = startApi();
    final List<String> requestIds = <String>[];
    api.onResumeReview =
        ({
          required String jobId,
          required String requestId,
          required String actionId,
          required String actor,
          String reviewerNote = '',
        }) async {
          requestIds.add(requestId);
          if (requestIds.length == 1) {
            throw const NetworkException();
          }
        };
    final StreamController<SseEvent> controller =
        StreamController<SseEvent>.broadcast();

    await tester.pumpWidget(
      screen(api, draft: _draft, events: eventsFor(controller.stream)),
    );
    await tapStart(tester);
    await emitGate(tester, controller);

    final Finder approve = find.text('Setujui');
    await tester.ensureVisible(approve);
    await tester.pump();
    await tester.tap(approve);
    await tester.pump();
    await tester.pump();

    expect(
      find.text(
        'Tidak dapat menghubungi server. Keputusan belum terkirim; coba lagi.',
      ),
      findsOneWidget,
    );
    expect(find.text(_requestId), findsOneWidget);
    expect(find.text('Setujui'), findsOneWidget);

    await tester.ensureVisible(find.text('Setujui'));
    await tester.pump();
    await tester.tap(find.text('Setujui'));
    await tester.pump();
    await tester.pump();

    expect(requestIds, <String>[_requestId, _requestId]);
    expect(find.text('Keputusan terkirim. Menunggu hasil…'), findsOneWidget);

    await disposeScreen(tester, controller);
  });

  testWidgets('output event renders the server confirmation and result', (
    tester,
  ) async {
    final FakeSyncareApi api = startApi();
    final StreamController<SseEvent> controller =
        StreamController<SseEvent>.broadcast();

    await tester.pumpWidget(
      screen(api, draft: _draft, events: eventsFor(controller.stream)),
    );
    await tapStart(tester);
    await emitGate(tester, controller);
    await emit(tester, controller, 'output', <String, dynamic>{
      'content': jsonEncode(<String, dynamic>{
        'action': 'approve',
        'confirmation': 'Rencana disetujui dan tersimpan.',
        'patient_id': 'demo-1',
        'approved_at': '2026-10-23T10:00:00Z',
        'reviewer_note': 'Setuju, kontrol 7 hari.',
      }),
    });

    expect(find.text('Persetujuan selesai'), findsOneWidget);
    expect(find.text('Rencana disetujui dan tersimpan.'), findsOneWidget);
    expect(find.text('approve'), findsOneWidget);
    expect(find.text('2026-10-23T10:00:00Z'), findsOneWidget);
    expect(find.text('Setuju, kontrol 7 hari.'), findsOneWidget);
    expect(find.text('Segarkan daftar rencana'), findsOneWidget);
    expect(find.text('Kembali ke draf'), findsOneWidget);

    await disposeScreen(tester, controller);
  });

  testWidgets('resume reopens the stream and delivers the terminal output', (
    tester,
  ) async {
    final FakeSyncareApi api = startApi();
    api.onResumeReview =
        ({
          required String jobId,
          required String requestId,
          required String actionId,
          required String actor,
          String reviewerNote = '',
        }) async {};
    final StreamController<SseEvent> controller =
        StreamController<SseEvent>.broadcast();
    int subscriptions = 0;
    final FakeReviewEventSource events = FakeReviewEventSource(
      onEvents: (_) {
        subscriptions += 1;
        return controller.stream;
      },
    );

    await tester.pumpWidget(screen(api, draft: _draft, events: events));
    await tapStart(tester);
    expect(subscriptions, 1);
    await emitGate(tester, controller);

    final Finder approve = find.text('Setujui');
    await tester.ensureVisible(approve);
    await tester.pump();
    await tester.tap(approve);
    await tester.pump();
    await tester.pump();

    // Langflow ends the old stream at the gate; the desk must resubscribe.
    expect(subscriptions, 2);

    await emit(tester, controller, 'output', <String, dynamic>{
      'content': jsonEncode(<String, dynamic>{
        'action': 'approve',
        'confirmation': 'Rencana disetujui dan tersimpan.',
        'patient_id': 'demo-1',
        'approved_at': '2026-10-23T10:00:00Z',
        'reviewer_note': '',
      }),
    });

    expect(find.text('Persetujuan selesai'), findsOneWidget);
    expect(find.text('Rencana disetujui dan tersimpan.'), findsOneWidget);

    await disposeScreen(tester, controller);
  });

  testWidgets('timeout shows the fallback escape hatch and resumes with it', (
    tester,
  ) async {
    final FakeSyncareApi api = startApi();
    String? sentAction;
    api.onResumeReview =
        ({
          required String jobId,
          required String requestId,
          required String actionId,
          required String actor,
          String reviewerNote = '',
        }) async {
          sentAction = actionId;
        };
    final StreamController<SseEvent> controller =
        StreamController<SseEvent>.broadcast();

    await tester.pumpWidget(
      screen(api, draft: _draft, events: eventsFor(controller.stream)),
    );
    await tapStart(tester);
    await emitGate(
      tester,
      controller,
      data: gateData(
        timeoutSeconds: 5,
        pausedAt: DateTime.now().subtract(const Duration(seconds: 30)),
      ),
    );

    expect(find.text('Batas waktu persetujuan habis'), findsOneWidget);
    expect(find.text('Setujui'), findsNothing);
    final Finder fallback = find.text('Kirim fallback');
    expect(fallback, findsOneWidget);
    await tester.ensureVisible(fallback);
    await tester.pump();
    await tester.tap(fallback);
    await tester.pump();
    await tester.pump();

    expect(sentAction, 'fallback');
    expect(find.text('Keputusan terkirim. Menunggu hasil…'), findsOneWidget);

    await disposeScreen(tester, controller);
  });

  testWidgets('stream error event renders the server text without a stack', (
    tester,
  ) async {
    final FakeSyncareApi api = startApi();
    final StreamController<SseEvent> controller =
        StreamController<SseEvent>.broadcast();

    await tester.pumpWidget(
      screen(api, draft: _draft, events: eventsFor(controller.stream)),
    );
    await tapStart(tester);
    await emit(tester, controller, 'error', <String, dynamic>{
      'data': <String, dynamic>{'text': 'Mesin gagal memproses rencana.'},
    });

    expect(find.text('Aliran persetujuan gagal'), findsOneWidget);
    expect(find.text('Mesin gagal memproses rencana.'), findsOneWidget);
    expect(find.textContaining('StackTrace'), findsNothing);
    expect(find.text('Buka ulang aliran'), findsOneWidget);

    await disposeScreen(tester, controller);
  });

  testWidgets('start failure shows ErrorState copy, not the raw exception', (
    tester,
  ) async {
    final FakeSyncareApi api = FakeSyncareApi();
    api.onStartReview = ({required String draftJson}) async {
      throw const NetworkException();
    };

    await tester.pumpWidget(
      screen(
        api,
        draft: _draft,
        events: eventsFor(const Stream<SseEvent>.empty()),
      ),
    );
    await tapStart(tester);

    expect(find.text('Tidak bisa menghubungi server'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);
    expect(find.textContaining('NetworkException'), findsNothing);
    expect(find.byType(DisclaimerBanner), findsOneWidget);

    await disposeScreen(tester);
  });

  testWidgets('unavailable stream offers a one-shot Langflow health check', (
    tester,
  ) async {
    final FakeSyncareApi api = startApi();
    api.onHealth = () async =>
        const Health(status: 'ok', langflow: 'reachable');

    await tester.pumpWidget(
      screen(
        api,
        draft: _draft,
        events: eventsFor(
          Stream<SseEvent>.error(const StreamUnavailableException()),
        ),
      ),
    );
    await tapStart(tester);
    await tester.pump();

    expect(find.text('Tidak bisa membuka aliran peristiwa'), findsOneWidget);
    expect(find.text('Periksa status layanan'), findsOneWidget);

    await tester.tap(find.text('Periksa status layanan'));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Langflow: reachable'), findsOneWidget);

    await disposeScreen(tester);
  });
}
