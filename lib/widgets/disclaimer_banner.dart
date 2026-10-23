import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Compact, always-visible notice that every value in the app comes from a
/// synthetic demo and is not medical advice.
class DisclaimerBanner extends StatelessWidget {
  const DisclaimerBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Semantics(
      container: true,
      label: 'Pemberitahuan demo sintetis',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.warningContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.warningOutline),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(
              Icons.science_outlined,
              size: 20,
              color: AppTheme.onWarningContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Demo sintetis — bukan nasihat medis',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.onWarningContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Seluruh keluaran dibuat untuk demonstrasi. Keputusan '
                    'klinis tetap di tangan tenaga kesehatan.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.onWarningContainer,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
