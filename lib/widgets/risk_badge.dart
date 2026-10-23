import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Only the three tiers the server actually emits are recognised; anything
/// else (including `null`) becomes a neutral "TIDAK DIKETAHUI" chip.
class RiskBadge extends StatelessWidget {
  const RiskBadge({super.key, required this.tier});

  final String? tier;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String trimmed = tier?.trim() ?? '';
    final String normalized = trimmed.toUpperCase();

    final _TierStyle style = switch (normalized) {
      'LOW' => const _TierStyle(
        semantics: 'Risiko rendah',
        background: AppTheme.lowContainer,
        foreground: AppTheme.onLowContainer,
        outline: AppTheme.lowOutline,
        icon: Icons.check_circle_outline,
      ),
      'MEDIUM' => const _TierStyle(
        semantics: 'Risiko sedang',
        background: AppTheme.mediumContainer,
        foreground: AppTheme.onMediumContainer,
        outline: AppTheme.mediumOutline,
        icon: Icons.warning_amber_rounded,
      ),
      'HIGH' => const _TierStyle(
        semantics: 'Risiko tinggi',
        background: AppTheme.highContainer,
        foreground: AppTheme.onHighContainer,
        outline: AppTheme.highOutline,
        icon: Icons.error_outline,
      ),
      _ => const _TierStyle(
        semantics: 'Risiko tidak diketahui',
        background: AppTheme.neutralContainer,
        foreground: AppTheme.onNeutralContainer,
        outline: AppTheme.neutralOutline,
        icon: Icons.help_outline,
      ),
    };

    final bool isKnownTier =
        normalized == 'LOW' || normalized == 'MEDIUM' || normalized == 'HIGH';
    final String displayText = isKnownTier ? trimmed : 'TIDAK DIKETAHUI';

    return Semantics(
      label: 'Tingkat risiko: ${style.semantics}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: style.background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: style.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(style.icon, size: 16, color: style.foreground),
            const SizedBox(width: 6),
            Text(
              displayText,
              style: theme.textTheme.labelLarge?.copyWith(
                color: style.foreground,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TierStyle {
  const _TierStyle({
    required this.semantics,
    required this.background,
    required this.foreground,
    required this.outline,
    required this.icon,
  });

  final String semantics;
  final Color background;
  final Color foreground;
  final Color outline;
  final IconData icon;
}
