import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncare_flutter/core/theme.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return ((x > y ? x : y) + 0.05) / ((x > y ? y : x) + 0.05);
}

void main() {
  test('brand, supporting surfaces, navigation and notice actions meet AA', () {
    final theme = AppTheme.light();
    final c = theme.colorScheme;
    final action = theme.outlinedButtonTheme.style!.foregroundColor!.resolve(
      {},
    )!;
    final pairs = [
      (c.onPrimary, c.primary),
      (c.onPrimaryContainer, c.primaryContainer),
      (c.onSecondary, c.secondary),
      (c.onSecondaryContainer, c.secondaryContainer),
      (c.onTertiary, c.tertiary),
      (c.onTertiaryContainer, c.tertiaryContainer),
      (c.onSurface, theme.scaffoldBackgroundColor),
      (c.onSurfaceVariant, c.surface),
      (c.onSurfaceVariant, theme.scaffoldBackgroundColor),
      (c.onError, c.error),
      (c.onErrorContainer, c.errorContainer),
      (c.onInverseSurface, c.inverseSurface),
      (action, c.surface),
      (action, c.errorContainer),
      (action, AppTheme.warningContainer),
    ];
    for (final (foreground, background) in pairs) {
      expect(contrast(foreground, background), greaterThanOrEqualTo(4.5));
    }
    expect(contrast(c.outline, c.surface), greaterThanOrEqualTo(3));
    expect(contrast(c.primary, c.surface), greaterThanOrEqualTo(3));
    for (final state in [
      WidgetState.hovered,
      WidgetState.focused,
      WidgetState.pressed,
    ]) {
      final background = theme.filledButtonTheme.style!.backgroundColor!
          .resolve({state})!;
      final withOverlay = Color.alphaBlend(
        c.onPrimary.withValues(alpha: 0.1),
        background,
      );
      expect(contrast(c.onPrimary, withOverlay), greaterThanOrEqualTo(4.5));
    }
  });
}
