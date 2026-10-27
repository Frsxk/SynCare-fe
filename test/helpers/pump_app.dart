import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:syncare_flutter/core/theme.dart';

/// Wraps one screen in the app's ProviderScope and MaterialApp theme.
///
/// Tests pass provider overrides (fakes) instead of touching live services.
Widget wrapScreen(Widget screen, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('id'),
      supportedLocales: const [Locale('id')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: screen,
    ),
  );
}
