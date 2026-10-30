import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/providers.dart';
import '../../models/escalation.dart';
import '../../widgets/error_state.dart';
import 'alert_providers.dart';
import 'checkin_providers.dart';

/// Exact patient-facing limits. A request records a nurse callback; it is not
/// an ambulance dispatch and never promises an immediate clinical response.
const emergencyRequestDisclaimer =
    'Permintaan dicatat untuk perawat; bukan panggilan ambulans/tidak menjamin bantuan segera';
const emergencyRequestWaitGuidance =
    'Jika ini keadaan darurat, jangan menunggu balasan aplikasi. Segera cari pertolongan medis langsung.';

sealed class EmergencyRequestState {
  const EmergencyRequestState();
}

class EmergencyRequestDraft extends EmergencyRequestState {
  const EmergencyRequestDraft({this.error});
  final Object? error;
}

class EmergencyRequestSending extends EmergencyRequestState {
  const EmergencyRequestSending();
}

/// The POST may have reached the server. The original key and payload are
/// retained so reconciliation replays the same request, never a new one.
class EmergencyRequestUnknown extends EmergencyRequestState {
  const EmergencyRequestUnknown(this.error, this.reason);
  final Object error;
  final String reason;
}

class EmergencyRequestUnavailable extends EmergencyRequestState {
  const EmergencyRequestUnavailable(this.error);
  final Object error;
}

class EmergencyRequestSaved extends EmergencyRequestState {
  const EmergencyRequestSaved(this.alert, {required this.replayed});
  final Escalation alert;
  final bool replayed;
}

final emergencyRequestProvider =
    StateNotifierProvider<EmergencyRequestController, EmergencyRequestState>(
      (ref) => EmergencyRequestController(
        ref.watch(apiProvider),
        ownCheckinPatient(ref),
      ),
    );

class EmergencyRequestController extends StateNotifier<EmergencyRequestState> {
  EmergencyRequestController(this.api, this.patientId)
    : super(
        patientId == null
            ? const EmergencyRequestUnavailable(UnauthorizedException())
            : const EmergencyRequestDraft(),
      );
  final SyncareApi api;
  final String? patientId;
  ({String reason, String key})? _intent;
  String? _draftReason;
  bool _busy = false;

  String get draftReason => _draftReason ?? '';

  Future<void> submit(String reason) async {
    final ownId = patientId, trimmed = reason.trim();
    if (ownId == null ||
        state is EmergencyRequestSending ||
        state is EmergencyRequestSaved ||
        state is EmergencyRequestUnavailable ||
        trimmed.isEmpty) {
      return;
    }
    // While the previous outcome is unknown only [retrySame] is allowed; an
    // edited reason must never mint a fresh key for the same emergency.
    if (state is EmergencyRequestUnknown) return;
    _intent ??= (reason: trimmed, key: requestUuid());
    _draftReason = _intent!.reason;
    await _send(_intent!);
  }

  Future<void> retrySame() async {
    final intent = _intent;
    if (intent == null || state is! EmergencyRequestUnknown) return;
    await _send(intent);
  }

  Future<void> _send(({String reason, String key}) intent) async {
    final ownId = patientId;
    if (ownId == null || _busy) return;
    _busy = true;
    state = const EmergencyRequestSending();
    try {
      final result = await api.requestEmergency(
        patientId: ownId,
        reason: intent.reason,
        requestKey: intent.key,
      );
      if (!mounted) return;
      if (result.alert.patientId != ownId) {
        throw const InvalidResponseException();
      }
      _intent = null;
      _draftReason = null;
      state = EmergencyRequestSaved(result.alert, replayed: result.replayed);
    } catch (error) {
      if (!mounted) return;
      if (error is ValidationException) {
        // 422 is a definitive rejection: nothing was stored, so the patient
        // may correct the reason; the next submit is a new intent.
        _intent = null;
        _draftReason = intent.reason;
        state = EmergencyRequestDraft(error: error);
      } else if (error is UnauthorizedException ||
          error is ForbiddenException ||
          error is NotFoundException ||
          error is ReadOnlyException) {
        _intent = null;
        _draftReason = intent.reason;
        state = EmergencyRequestUnavailable(error);
      } else {
        // Timeout, transport reset, 5xx, malformed 201: the write may exist.
        state = EmergencyRequestUnknown(error, intent.reason);
      }
    } finally {
      _busy = false;
    }
  }

  void startNew() {
    if (state is! EmergencyRequestSaved) return;
    _intent = null;
    _draftReason = null;
    state = const EmergencyRequestDraft();
  }
}

class EmergencyRequestPanel extends ConsumerStatefulWidget {
  const EmergencyRequestPanel({super.key});
  @override
  ConsumerState<EmergencyRequestPanel> createState() =>
      _EmergencyRequestPanelState();
}

class _EmergencyRequestPanelState
    extends ConsumerState<EmergencyRequestPanel> {
  late final TextEditingController _reason;
  bool _confirming = false;
  bool _missingReason = false;

  @override
  void initState() {
    super.initState();
    _reason = TextEditingController(
      text: ref.read(emergencyRequestProvider.notifier).draftReason,
    );
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _askForConfirmation() async {
    if (_confirming) return;
    final text = _reason.text.trim();
    if (text.isEmpty) {
      setState(() => _missingReason = true);
      return;
    }
    setState(() {
      _confirming = true;
      _missingReason = false;
    });
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EmergencyConfirmDialog(reason: text),
    );
    if (!mounted) return;
    setState(() => _confirming = false);
    if (confirmed == true) {
      await ref.read(emergencyRequestProvider.notifier).submit(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(emergencyRequestProvider);
    ref.listen(emergencyRequestProvider, (previous, next) {
      if (next is EmergencyRequestSaved &&
          previous is! EmergencyRequestSaved) {
        _reason.clear();
      }
    });
    // Route guards keep this screen patient-only; during session restore the
    // panel simply stays out of the way instead of claiming an auth failure.
    if (state is EmergencyRequestUnavailable &&
        state.error is UnauthorizedException) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final formEnabled = state is EmergencyRequestDraft;
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Bantuan darurat',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Kirim permintaan ke antrean perawat untuk ditinjau.',
            ),
            const SizedBox(height: 8),
            Text(
              emergencyRequestDisclaimer,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(emergencyRequestWaitGuidance),
            const SizedBox(height: 16),
            ...switch (state) {
              EmergencyRequestDraft(:final error) => [
                TextField(
                  controller: _reason,
                  enabled: formEnabled,
                  maxLines: 3,
                  maxLength: 8000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Alasan permintaan',
                    hintText: 'Contoh: sesak berat sejak tadi.',
                  ),
                  onChanged: (_) {
                    if (_missingReason) {
                      setState(() => _missingReason = false);
                    }
                  },
                ),
                if (_missingReason)
                  const Text(
                    'Tulis alasan permintaan terlebih dahulu.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  ErrorState(error: error),
                ],
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: formEnabled ? _askForConfirmation : null,
                  child: const Text('Minta bantuan segera'),
                ),
              ],
              EmergencyRequestSending() => [
                Semantics(
                  liveRegion: true,
                  child: const Text(
                    'Mengirim permintaan... Jangan menutup halaman ini.',
                  ),
                ),
                const SizedBox(height: 12),
                const FilledButton(
                  onPressed: null,
                  child: Text('Mengirim permintaan...'),
                ),
              ],
              EmergencyRequestUnknown(:final error, :final reason) => [
                ErrorState(error: error),
                const SizedBox(height: 8),
                Text(reason),
                const SizedBox(height: 8),
                const Text(
                  'Hasil permintaan belum dapat dipastikan. Periksa permintaan yang sama; jangan membuat permintaan baru dengan kunci berbeda.',
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () =>
                      ref.read(emergencyRequestProvider.notifier).retrySame(),
                  child: const Text('Periksa permintaan yang sama'),
                ),
              ],
              EmergencyRequestUnavailable(:final error) => [
                ErrorState(error: error),
              ],
              EmergencyRequestSaved(:final alert, :final replayed) => [
                Semantics(
                  liveRegion: true,
                  container: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Permintaan tercatat',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Status: ${alert.status.label}'),
                      const SizedBox(height: 8),
                      Text(alert.reason),
                      const SizedBox(height: 8),
                      const Text(
                        'Permintaan masuk antrean perawat. Jika ini keadaan darurat, tetap cari pertolongan medis langsung dan jangan menunggu balasan aplikasi.',
                      ),
                      if (replayed) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Permintaan ini sudah tercatat sebelumnya. Tidak ada permintaan duplikat yang dibuat.',
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(alertHistoryProvider),
                  child: const Text('Muat ulang status tindak lanjut'),
                ),
                TextButton(
                  onPressed: () =>
                      ref.read(emergencyRequestProvider.notifier).startNew(),
                  child: const Text('Buat permintaan baru'),
                ),
              ],
            },
          ],
        ),
      ),
    );
  }
}

class _EmergencyConfirmDialog extends StatefulWidget {
  const _EmergencyConfirmDialog({required this.reason});
  final String reason;
  @override
  State<_EmergencyConfirmDialog> createState() =>
      _EmergencyConfirmDialogState();
}

class _EmergencyConfirmDialogState extends State<_EmergencyConfirmDialog> {
  bool _submitted = false;

  void _cancel() {
    if (_submitted) return;
    Navigator.of(context).pop(false);
  }

  void _confirm() {
    if (_submitted) return;
    setState(() => _submitted = true);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Kirim permintaan ke perawat?'),
    content: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Alasan permintaan:'),
          const SizedBox(height: 4),
          Text(widget.reason),
          const SizedBox(height: 12),
          const Text(
            'Permintaan masuk antrean perawat. Ini bukan panggilan ambulans dan tidak menjamin bantuan segera.',
          ),
          const SizedBox(height: 8),
          const Text(emergencyRequestWaitGuidance),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _submitted ? null : _cancel,
        child: const Text('Batal'),
      ),
      FilledButton(
        onPressed: _submitted ? null : _confirm,
        child: const Text('Ya, kirim permintaan'),
      ),
    ],
  );
}
