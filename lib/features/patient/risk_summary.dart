import 'package:flutter/material.dart';
import '../../models/patient.dart';
import '../../widgets/risk_badge.dart';

class RiskSummary extends StatelessWidget {
  const RiskSummary({required this.risk, this.urgentReason, super.key});
  final ConfirmedRisk risk;
  final String? urgentReason;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Kategori risiko saya',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 16),
      if (urgentReason case final String reason) ...[
        Semantics(
          liveRegion: true,
          child: Text(
            'Peringatan mendesak: $reason',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 16),
      ],
      if (risk.current case final ConfirmedRiskEvidence evidence) ...[
        const Text('Kategori dikonfirmasi perawat'),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: RiskBadge(tier: evidence.category),
        ),
      ] else
        Semantics(
          liveRegion: true,
          child: Text(
            risk.status == 'needs_reassessment'
                ? 'Perlu penilaian dan konfirmasi ulang karena ringkasan pulang berubah.'
                : 'Belum ada kategori risiko yang dikonfirmasi perawat.',
          ),
        ),
    ],
  );
}
