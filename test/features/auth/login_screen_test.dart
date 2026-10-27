import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncare_flutter/app.dart';
import 'package:syncare_flutter/core/session_api.dart';
import 'package:syncare_flutter/core/theme.dart';
import 'package:syncare_flutter/features/auth/login_screen.dart';
import 'package:syncare_flutter/models/session.dart';

import '../../helpers/fakes.dart';
import 'session_controller_test.dart' show FakeSessionApi;

void main() {
  testWidgets(
    'login reflows at 320px and 200 percent text, remains scrollable and masks the password',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final api = FakeSessionApi();
      final capture = Platform.environment['SYNCARE_CAPTURE_WIDGETS'] == 'true';
      if (capture) {
        await tester.runAsync(() async {
          final sdk = Directory(Platform.environment['SYNCARE_FLUTTER_SDK']!);
          final fonts = sdk.uri.resolve('bin/cache/artifacts/material_fonts/');
          for (final family in ['Ahem', 'Roboto']) {
            final loader = FontLoader(family);
            for (final file in ['roboto-regular.ttf', 'roboto-bold.ttf']) {
              loader.addFont(
                File.fromUri(
                  fonts.resolve(file),
                ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
              );
            }
            await loader.load();
          }
          final icons = FontLoader('MaterialIcons')
            ..addFont(
              File.fromUri(
                fonts.resolve('materialicons-regular.otf'),
              ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
            );
          await icons.load();
        });
      }
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionApiProvider.overrideWithValue(api),
            tokenSourceProvider.overrideWithValue(FakeTokenSource()),
          ],
          child: const RepaintBoundary(child: SynCareApp()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final theme = Theme.of(tester.element(find.byType(LoginScreen)));
      for (final pair in [
        (theme.colorScheme.onSurface, theme.scaffoldBackgroundColor),
        (theme.colorScheme.onSurfaceVariant, theme.scaffoldBackgroundColor),
        (theme.colorScheme.onPrimary, theme.colorScheme.primary),
        (AppTheme.onWarningContainer, AppTheme.warningContainer),
      ]) {
        final first = pair.$1.computeLuminance();
        final second = pair.$2.computeLuminance();
        final lighter = first > second ? first : second;
        final darker = first > second ? second : first;
        expect((lighter + 0.05) / (darker + 0.05), greaterThanOrEqualTo(4.5));
      }
      if (capture) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byType(RepaintBoundary).first,
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '../.tools/m02-flutter-login-320-text200.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      final password = find.widgetWithText(TextField, 'Kata sandi');
      expect(tester.widget<TextField>(password).obscureText, isTrue);
      final submit = find.widgetWithText(FilledButton, 'Masuk');
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      if (capture) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byType(RepaintBoundary).first,
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '../.tools/m02-flutter-login-form-320-text200.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(
        find.text('Isi identitas akun dan kata sandi terlebih dahulu.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'keyboard submission shows a typed retryable failure and preserves the entered identifier',
    (tester) async {
      var attempts = 0;
      final api = FakeSessionApi()
        ..onLogin = (_, _) async {
          attempts++;
          throw const SessionException(SessionFailure.unavailable);
        };
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionApiProvider.overrideWithValue(api),
            tokenSourceProvider.overrideWithValue(FakeTokenSource()),
          ],
          child: const SynCareApp(),
        ),
      );
      await tester.pumpAndSettle();
      final identifier = find.widgetWithText(TextField, 'Identitas akun');
      final password = find.widgetWithText(TextField, 'Kata sandi');
      await tester.enterText(identifier, 'synthetic-patient');
      await tester.enterText(password, 'synthetic-password');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(attempts, 1);
      expect(find.text(SessionFailure.unavailable.message), findsOneWidget);
      expect(
        tester.widget<TextField>(identifier).controller?.text,
        'synthetic-patient',
      );
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Masuk'));
      await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
    },
  );
}
