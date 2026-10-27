import 'package:flutter/material.dart';

/// Risk colours deliberately use dark foregrounds on light tinted surfaces
/// (>= 7:1 contrast) instead of saturated pastels, so the tier text stays
/// readable for low-vision users in bright clinical environments.
class AppTheme {
  const AppTheme._();

  static const Color seedColor = Color(0xFF108444);

  // Risk tier surfaces and their readable foregrounds.
  static const Color lowContainer = Color(0xFFC9F0DC);
  static const Color onLowContainer = Color(0xFF075233);
  static const Color lowOutline = Color(0xFF1F8A5B);

  static const Color mediumContainer = Color(0xFFFFE2A8);
  static const Color onMediumContainer = Color(0xFF5A3B00);
  static const Color mediumOutline = Color(0xFFB07A00);

  static const Color highContainer = Color(0xFFFFD5D1);
  static const Color onHighContainer = Color(0xFF7A0F0F);
  static const Color highOutline = Color(0xFFC0392B);

  static const Color neutralContainer = Color(0xFFE3EAE7);
  static const Color onNeutralContainer = Color(0xFF33433F);
  static const Color neutralOutline = Color(0xFF9AA8A4);

  /// Banner palette: amber, clearly a notice without reading as an error.
  static const Color warningContainer = Color(0xFFFFF3D6);
  static const Color onWarningContainer = Color(0xFF4A3600);
  static const Color warningOutline = Color(0xFFD9A400);

  static ThemeData light() {
    const ColorScheme scheme = ColorScheme(
      brightness: Brightness.light,
      primary: seedColor,
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFE8F5EE),
      onPrimaryContainer: Color(0xFF0D5C32),
      secondary: Color(0xFF264282),
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFEDF1FA),
      onSecondaryContainer: Color(0xFF264282),
      tertiary: Color(0xFF52648B),
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFFABB4CC),
      onTertiaryContainer: Color(0xFF264282),
      error: Color(0xFFB3261E),
      onError: Color(0xFFFFFFFF),
      errorContainer: highContainer,
      onErrorContainer: onHighContainer,
      surface: Color(0xFFFFFFFF),
      onSurface: Color(0xFF17283B),
      onSurfaceVariant: Color(0xFF4A576C),
      outline: Color(0xFF64748B),
      outlineVariant: Color(0xFFDBE3EF),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFF17283B),
      onInverseSurface: Color(0xFFF4F6FA),
      inversePrimary: Color(0xFF92D6B0),
      surfaceDim: Color(0xFFE2E7F0),
      surfaceBright: Color(0xFFFFFFFF),
      surfaceContainerLowest: Color(0xFFFFFFFF),
      surfaceContainerLow: Color(0xFFF4F6FA),
      surfaceContainer: Color(0xFFEDF1F7),
      surfaceContainerHigh: Color(0xFFE6EBF3),
      surfaceContainerHighest: Color(0xFFDFE5EF),
    );

    final ThemeData base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surfaceContainerLow,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.secondaryContainer,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.secondary
                : scheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? scheme.secondary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      appBarTheme: AppBarThemeData(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              minimumSize: const Size(64, 48),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ).copyWith(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) return null;
                if (states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.focused) ||
                    states.contains(WidgetState.pressed)) {
                  return const Color(0xFF0C6B37);
                }
                return scheme.primary;
              }),
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          foregroundColor: scheme.secondary,
          side: BorderSide(color: scheme.outline),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          foregroundColor: scheme.secondary,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.all(12),
          foregroundColor: scheme.onSurfaceVariant,
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        floatingLabelStyle: TextStyle(color: scheme.primary),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        helperStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
        errorStyle: TextStyle(color: scheme.error, fontSize: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        contentTextStyle: TextStyle(
          fontSize: 15,
          height: 1.45,
          color: scheme.onSurfaceVariant,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(
          color: scheme.onInverseSurface,
          fontSize: 14,
          height: 1.4,
        ),
        actionTextColor: scheme.inversePrimary,
        elevation: 4,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(color: scheme.onInverseSurface, fontSize: 13),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minVerticalPadding: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
      bottomSheetTheme: const BottomSheetThemeData(
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        headlineLarge: base.textTheme.headlineLarge?.copyWith(
          color: scheme.secondary,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          color: scheme.secondary,
          fontWeight: FontWeight.w700,
          height: 1.25,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.5),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.45),
        bodySmall: base.textTheme.bodySmall?.copyWith(height: 1.4),
        labelLarge: base.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
