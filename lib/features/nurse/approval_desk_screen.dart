import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_exception.dart';
import '../../core/config.dart';
import '../../core/providers.dart';
import '../../core/sse.dart';
import '../../models/health.dart';
import '../../models/plan_draft.dart';
import '../../models/review_job.dart';
import '../../widgets/disclaimer_banner.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/risk_badge.dart';
import '../../widgets/token_dialog.dart';

/// Nurse human-in-the-loop approval console.
///
/// The screen never computes a decision: it forwards the nurse's choice to the
/// backend through the typed API and renders whatever the review stream emits.
class NurseApprovalDeskScreen extends ConsumerStatefulWidget {
  const NurseApprovalDeskScreen({super.key});

  @override
  ConsumerState<NurseApprovalDeskScreen> createState() =>
      _NurseApprovalDeskScreenState();
}

enum _DeskPhase { idle, starting, waiting, gate, result, error }

class _NurseApprovalDeskScreenState
    extends ConsumerState<NurseApprovalDeskScreen> {
  static const TextStyle _monoStyle = TextStyle(
    fontFamily: 'monospace',
    fontSize: 13,
    height: 1.35,
  );

  final TextEditingController _reviewerController = TextEditingController(
    text: AppConfig.defaultReviewer,
  );
  final TextEditingController _noteController = TextEditingController();

  _DeskPhase _phase = _DeskPhase.idle;
  String? _jobId;
  DateTime? _startedAt;
  Duration _elapsed = Duration.zero;
  HumanGate? _gate;
  int _remaining = 0;
  ReviewOutput? _result;
  bool _decided = false;
  bool _submitting = false;
  Object? _error;
  String? _errorText;
  String? _gateError;
  Health? _health;
  bool _healthLoading = false;
  bool _healthFailed = false;

  StreamSubscription<SseEvent>? _subscription;
  Timer? _ticker;

  @override
  void dispose() {
    _cancelSubscription();
    _cancelTicker();
    _reviewerController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String get _actor {
    final String value = _reviewerController.text.trim();
    return value.isEmpty ? AppConfig.defaultReviewer : value;
  }

  // ---------------------------------------------------------------------------
  // Review lifecycle
  // ---------------------------------------------------------------------------

  Future<void> _startReview() async {
    final PlanDraft? draft = ref.read(draftResultProvider);
    if (draft == null || _phase == _DeskPhase.starting) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    _cancelSubscription();
    _cancelTicker();
    setState(() {
      _phase = _DeskPhase.starting;
      _jobId = null;
      _startedAt = null;
      _elapsed = Duration.zero;
      _gate = null;
      _remaining = 0;
      _result = null;
      _decided = false;
      _submitting = false;
      _error = null;
      _errorText = null;
      _gateError = null;
      _health = null;
      _healthLoading = false;
      _healthFailed = false;
    });

    try {
      final ReviewJob job = await ref
          .read(apiProvider)
          .startReview(draftJson: jsonEncode(draft.rawJson));
      if (!mounted) {
        return;
      }
      final String jobId = job.jobId.trim();
      if (jobId.isEmpty) {
        _failWith(const InvalidResponseException());
        return;
      }
      setState(() {
        _jobId = jobId;
        _startedAt = DateTime.now();
        _elapsed = Duration.zero;
        _phase = _DeskPhase.waiting;
      });
      _ensureTicker();
      _subscribe(jobId);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _failWith(error);
    }
  }

  void _subscribe(String jobId) {
    _cancelSubscription();

    final Stream<SseEvent> stream;
    try {
      stream = ref.read(reviewEventsProvider).events(jobId);
    } catch (error) {
      _failWith(error);
      return;
    }

    try {
      _subscription = stream.listen(
        _handleEvent,
        onError: (Object error, StackTrace _) {
          if (!mounted) {
            return;
          }
          _failWith(error);
        },
        onDone: _handleStreamDone,
        cancelOnError: true,
      );
    } catch (error) {
      _failWith(error);
    }
  }

  void _resubscribe() {
    final String? jobId = _jobId;
    if (jobId == null) {
      _startReview();
      return;
    }
    setState(() {
      _phase = _gate != null && !_decided
          ? _DeskPhase.gate
          : _DeskPhase.waiting;
      _error = null;
      _errorText = null;
      _gateError = null;
      _submitting = false;
      _health = null;
      _healthLoading = false;
      _healthFailed = false;
    });
    _ensureTicker();
    _subscribe(jobId);
  }

  void _retryAfterError() {
    if (_jobId == null) {
      _startReview();
    } else {
      _resubscribe();
    }
  }

  void _cancelReview() {
    _cancelSubscription();
    _cancelTicker();
    if (!mounted) {
      return;
    }
    setState(() {
      _phase = _DeskPhase.idle;
      _jobId = null;
      _startedAt = null;
      _elapsed = Duration.zero;
      _gate = null;
      _remaining = 0;
      _result = null;
      _decided = false;
      _submitting = false;
      _error = null;
      _errorText = null;
      _gateError = null;
      _health = null;
      _healthLoading = false;
      _healthFailed = false;
    });
  }

  void _handleEvent(SseEvent event) {
    if (!mounted ||
        _phase == _DeskPhase.idle ||
        _phase == _DeskPhase.starting ||
        _phase == _DeskPhase.result ||
        _phase == _DeskPhase.error) {
      return;
    }
    final NormalizedSseEvent normalized = normalizeSseEvent(event);
    switch (normalized.name) {
      case 'human_input_required':
        _handleGate(normalized.data);
      case 'output':
        _handleOutput(normalized.data);
      case 'error':
        _failEvent(_eventErrorText(normalized.data));
      case 'end':
        if (_phase == _DeskPhase.waiting && _result == null) {
          _failEvent('Aliran berakhir tanpa hasil.');
        }
    }
  }

  void _handleGate(Map<String, dynamic> data) {
    if (_decided || _gate != null || _result != null) {
      return;
    }
    final HumanGate gate = HumanGate.fromJson(data);
    if (gate.requestId.trim().isEmpty) {
      _failEvent('Server tidak mengirim request_id untuk gerbang persetujuan.');
      return;
    }
    setState(() {
      _gate = gate;
      _remaining = gate.remainingSeconds(DateTime.now());
      _phase = _DeskPhase.gate;
      _gateError = null;
      _error = null;
      _errorText = null;
      _submitting = false;
    });
    _ensureTicker();
  }

  void _handleOutput(Map<String, dynamic> data) {
    final Object? rawContent = data['content'];
    final ReviewOutput output = ReviewOutput.fromContent(
      rawContent is String ? rawContent : '',
    );
    _cancelSubscription();
    _cancelTicker();
    if (!mounted) {
      return;
    }
    setState(() {
      _result = output;
      _phase = _DeskPhase.result;
      _decided = true;
      _gate = null;
      _gateError = null;
      _remaining = 0;
      _submitting = false;
      _error = null;
      _errorText = null;
    });
    ref.invalidate(plansProvider);
  }

  void _handleStreamDone() {
    if (!mounted) {
      return;
    }
    if (_phase == _DeskPhase.waiting && _result == null) {
      _failEvent('Aliran berakhir tanpa hasil.');
    }
  }

  void _failWith(Object error) {
    _cancelSubscription();
    _cancelTicker();
    if (!mounted) {
      return;
    }
    setState(() {
      _phase = _DeskPhase.error;
      _error = error;
      _errorText = null;
      _gate = null;
      _gateError = null;
      _submitting = false;
    });
  }

  void _failEvent(String message) {
    _cancelSubscription();
    _cancelTicker();
    if (!mounted) {
      return;
    }
    setState(() {
      _phase = _DeskPhase.error;
      _error = null;
      _errorText = message;
      _submitting = false;
    });
  }

  String _eventErrorText(Map<String, dynamic> data) {
    final Object? direct = data['text'];
    if (direct is String && direct.trim().isNotEmpty) {
      return direct.trim();
    }
    final Object? nested = data['data'];
    if (nested is Map) {
      final Object? text = nested['text'];
      if (text is String && text.trim().isNotEmpty) {
        return text.trim();
      }
    }
    return 'Server melaporkan kesalahan pada aliran persetujuan.';
  }

  Future<void> _submit(String actionId) async {
    final HumanGate? gate = _gate;
    final String? jobId = _jobId;
    if (gate == null || jobId == null || _submitting) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _submitting = true;
      _gateError = null;
    });

    try {
      await ref
          .read(apiProvider)
          .resumeReview(
            jobId: jobId,
            requestId: gate.requestId,
            actionId: actionId,
            actor: _actor,
            reviewerNote: _noteController.text.trim(),
          );
      if (!mounted) {
        return;
      }
      if (_phase == _DeskPhase.result) {
        setState(() {
          _submitting = false;
        });
        return;
      }
      setState(() {
        _submitting = false;
        _decided = true;
        _gate = null;
        _gateError = null;
        _remaining = 0;
        _phase = _DeskPhase.waiting;
      });
      _ensureTicker();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        if (_phase == _DeskPhase.gate) {
          _gateError = _resumeErrorMessage(error);
        }
      });
    }
  }

  Future<void> _submitFallback() async {
    final HumanGate? gate = _gate;
    if (gate == null) {
      return;
    }
    final String action = gate.fallbackAction.trim().isEmpty
        ? 'fallback'
        : gate.fallbackAction.trim();
    await _submit(action);
  }

  String _resumeErrorMessage(Object error) {
    if (error is UnauthorizedException) {
      return 'Sesi tidak valid. Perbarui token lalu kirim ulang keputusan.';
    }
    if (error is ReadOnlyException) {
      return 'Server dalam mode baca-saja; keputusan tidak dapat dikirim.';
    }
    if (error is ValidationException) {
      return 'Server menolak keputusan ini. Periksa isian lalu coba lagi.';
    }
    if (error is NotFoundException) {
      return 'Pekerjaan persetujuan tidak ditemukan. Buka ulang aliran.';
    }
    if (error is StreamUnavailableException) {
      return 'Aliran persetujuan tidak tersedia. Keputusan belum terkirim; '
          'coba lagi.';
    }
    if (error is NetworkException) {
      return 'Tidak dapat menghubungi server. Keputusan belum terkirim; '
          'coba lagi.';
    }
    return 'Keputusan gagal dikirim. Permintaan belum diterima server; '
        'coba lagi.';
  }

  void _ensureTicker() {
    if (_ticker != null && _ticker!.isActive) {
      return;
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      final DateTime now = DateTime.now();
      final DateTime? startedAt = _startedAt;
      setState(() {
        _elapsed = startedAt == null
            ? Duration.zero
            : now.difference(startedAt);
        final HumanGate? gate = _gate;
        if (gate != null) {
          _remaining = gate.remainingSeconds(now);
        }
      });
    });
  }

  void _cancelTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _cancelSubscription() {
    final StreamSubscription<SseEvent>? subscription = _subscription;
    _subscription = null;
    subscription?.cancel();
  }

  Future<void> _checkHealth() async {
    if (_healthLoading) {
      return;
    }
    setState(() {
      _healthLoading = true;
      _healthFailed = false;
    });
    try {
      final Health health = await ref.read(apiProvider).health();
      if (!mounted) {
        return;
      }
      setState(() {
        _health = health;
        _healthLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _healthLoading = false;
        _healthFailed = true;
      });
    }
  }

  String _formatClock(int seconds) {
    final int safe = seconds < 0 ? 0 : seconds;
    final int minutes = safe ~/ 60;
    final int rest = safe % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${rest.toString().padLeft(2, '0')}';
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final PlanDraft? draft = ref.watch(draftResultProvider);
    final String patientId = ref.watch(patientIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Meja Persetujuan')),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: DisclaimerBanner(),
            ),
            Expanded(child: _buildBody(draft, patientId)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(PlanDraft? draft, String patientId) {
    if (draft == null) {
      return _buildEmpty();
    }
    return switch (_phase) {
      _DeskPhase.idle => _buildIdle(draft, patientId),
      _DeskPhase.starting => _buildStarting(),
      _DeskPhase.waiting => _buildWaiting(patientId),
      _DeskPhase.gate =>
        _gate == null
            ? _buildWaiting(patientId)
            : _buildGate(draft, patientId, _gate!),
      _DeskPhase.result =>
        _result == null
            ? _buildWaiting(patientId)
            : _buildResult(patientId, _result!),
      _DeskPhase.error => _buildError(patientId),
    };
  }

  Widget _buildEmpty() {
    return Column(
      children: <Widget>[
        const Expanded(
          child: EmptyState(
            title: 'Belum ada draf',
            message:
                'Buat draf rencana terlebih dahulu sebelum mengirimnya ke '
                'meja persetujuan.',
            icon: Icons.note_add_outlined,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.go('/nurse/draft'),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Ke draf'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStarting() {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Memulai aliran persetujuan…',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdle(PlanDraft draft, String patientId) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: <Widget>[
        _patientCaption(patientId),
        const SizedBox(height: 12),
        _draftSummary(draft),
        const SizedBox(height: 16),
        TextField(
          controller: _reviewerController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Nama peninjau',
            helperText: 'Nama yang akan tercatat pada keputusan.',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _noteController,
          minLines: 2,
          maxLines: 4,
          textInputAction: TextInputAction.newline,
          decoration: const InputDecoration(
            labelText: 'Catatan peninjau (opsional)',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _startReview,
            icon: const Icon(Icons.send_outlined),
            label: const Text('Kirim ke meja persetujuan'),
          ),
        ),
      ],
    );
  }

  Widget _buildWaiting(String patientId) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: <Widget>[
        _patientCaption(patientId),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Menunggu persetujuan',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _decided
                      ? 'Keputusan terkirim. Menunggu hasil…'
                      : 'Aliran peristiwa terbuka. Hasil akan muncul otomatis '
                            'tanpa polling.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Waktu berjalan: ${_formatClock(_elapsed.inSeconds)}',
                  style: theme.textTheme.bodyMedium,
                ),
                if (_jobId != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    'ID pekerjaan',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  SelectableText(_jobId!, style: _monoStyle),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _resubscribe,
            icon: const Icon(Icons.refresh),
            label: const Text('Buka ulang aliran'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: _cancelReview,
            child: const Text('Batalkan'),
          ),
        ),
      ],
    );
  }

  Widget _buildGate(PlanDraft draft, String patientId, HumanGate gate) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool timedOut = _remaining <= 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: <Widget>[
        _patientCaption(patientId),
        const SizedBox(height: 12),
        _draftSummary(draft),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Persetujuan manusia diperlukan',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tinjau draf di atas, lalu pilih satu keputusan. Server '
                  'menentukan hasil akhirnya.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'ID permintaan',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(gate.requestId, style: _monoStyle),
                const SizedBox(height: 12),
                Text(
                  'Sisa waktu: ${_formatClock(_remaining)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: timedOut ? scheme.error : null,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _reviewerController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nama peninjau',
                    helperText: 'Nama yang akan tercatat pada keputusan.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _noteController,
                  minLines: 2,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    labelText: 'Catatan peninjau (opsional)',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_gateError != null) _inlineError(_gateError!),
                const SizedBox(height: 16),
                if (timedOut)
                  _timeoutPanel(gate)
                else
                  ..._decisionButtons(gate),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _decisionButtons(HumanGate gate) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool allowApprove = _permits(gate, 'approve');
    final bool allowChanges = _permits(gate, 'request_changes');
    final bool allowEscalate = _permits(gate, 'escalate');
    final bool allowFallback = _permits(gate, 'fallback');

    return <Widget>[
      if (allowApprove)
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _submitting ? null : () => _submit('approve'),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Setujui'),
          ),
        ),
      if (allowChanges) ...<Widget>[
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _submitting ? null : () => _submit('request_changes'),
            icon: const Icon(Icons.edit_note),
            label: const Text('Minta Perubahan'),
          ),
        ),
      ],
      if (allowEscalate) ...<Widget>[
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: _submitting ? null : () => _submit('escalate'),
            icon: const Icon(Icons.emergency_outlined),
            label: const Text('Eskalasi'),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Eskalasi adalah tindakan serius: segera libatkan tim klinis.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: scheme.error),
        ),
      ],
      if (allowFallback) ...<Widget>[
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _submitting ? null : () => _submit('fallback'),
            icon: const Icon(Icons.replay),
            label: const Text('Fallback'),
          ),
        ),
      ],
      if (_submitting) ...<Widget>[
        const SizedBox(height: 12),
        const LinearProgressIndicator(),
      ],
    ];
  }

  bool _permits(HumanGate gate, String action) {
    if (gate.allowedDecisions.isEmpty) {
      return true;
    }
    return gate.allowedDecisions.contains(action);
  }

  Widget _timeoutPanel(HumanGate gate) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.error),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.timer_off_outlined, color: scheme.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Batas waktu persetujuan habis',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.onErrorContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Jendela persetujuan sudah lewat. Pekerjaan di server mungkin '
            'masih tertunda atau sudah kedaluwarsa. Kirim fallback agar server '
            'melanjutkan sesuai kebijakan alur; status akhirnya tetap '
            'ditentukan server.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onErrorContainer,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _submitting ? null : _submitFallback,
              icon: const Icon(Icons.replay),
              label: const Text('Kirim fallback'),
            ),
          ),
          if (_submitting) ...<Widget>[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }

  Widget _buildResult(String patientId, ReviewOutput output) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: <Widget>[
        _patientCaption(patientId),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(Icons.task_alt, color: scheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Persetujuan selesai',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  output.confirmation.trim().isEmpty
                      ? 'Server tidak mengirim teks konfirmasi.'
                      : output.confirmation,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
                ),
                _serverField('Aksi', output.action),
                _serverField('ID pasien (server)', output.patientId),
                _serverField('Disetujui pada', output.approvedAt),
                _serverField('Catatan peninjau', output.reviewerNote),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              ref.invalidate(plansProvider);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Daftar rencana akan disegarkan.'),
                ),
              );
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Segarkan daftar rencana'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => context.go('/nurse/draft'),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Kembali ke draf'),
          ),
        ),
      ],
    );
  }

  Widget _buildError(String patientId) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final String? errorText = _errorText;

    if (errorText != null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: <Widget>[
          _patientCaption(patientId),
          const SizedBox(height: 12),
          Card(
            color: scheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(Icons.error_outline, color: scheme.onErrorContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Aliran persetujuan gagal',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: scheme.onErrorContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    errorText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onErrorContainer,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _retryAfterError,
              icon: const Icon(Icons.refresh),
              label: const Text('Buka ulang aliran'),
            ),
          ),
        ],
      );
    }

    final Object error =
        _error ?? const UnexpectedApiException('Aliran persetujuan gagal.');
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: _patientCaption(patientId),
          ),
        ),
        Expanded(
          child: ErrorState(
            error: error,
            onRetry: _retryAfterError,
            onReauth: () => showTokenDialog(context, ref),
          ),
        ),
        if (error is StreamUnavailableException) _buildServiceCheck(),
      ],
    );
  }

  Widget _buildServiceCheck() {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Health? health = _health;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (health == null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _healthLoading ? null : _checkHealth,
                icon: const Icon(Icons.monitor_heart_outlined),
                label: Text(
                  _healthLoading
                      ? 'Memeriksa layanan…'
                      : 'Periksa status layanan',
                ),
              ),
            ),
          if (_healthLoading)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(),
            ),
          if (health != null)
            Card(
              margin: const EdgeInsets.only(top: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Status layanan',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Langflow: '
                      '${health.langflow.trim().isEmpty ? 'tidak dilaporkan server' : health.langflow.trim()}',
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      'Status server: '
                      '${health.status.trim().isEmpty ? 'tidak dilaporkan server' : health.status.trim()}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          if (_healthFailed)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Status layanan tidak dapat diperiksa saat ini.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
              ),
            ),
        ],
      ),
    );
  }

  Widget _draftSummary(PlanDraft draft) {
    final ThemeData theme = Theme.of(context);
    final String planText = draft.planText.trim();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Draf rencana',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                RiskBadge(tier: draft.tier),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText(
              planText.isEmpty ? 'Draf tidak memuat teks rencana.' : planText,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
          ],
        ),
      ),
    );
  }

  Widget _patientCaption(String patientId) {
    final ThemeData theme = Theme.of(context);
    return Text(
      'ID pasien: $patientId',
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _serverField(String label, String value) {
    final ThemeData theme = Theme.of(context);
    final String trimmed = value.trim();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          SelectableText(
            trimmed.isEmpty ? 'Tidak tersedia' : trimmed,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _inlineError(String message) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.error_outline, size: 20, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onErrorContainer,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
