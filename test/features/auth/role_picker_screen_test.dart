import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncare_flutter/core/config.dart';
import 'package:syncare_flutter/core/providers.dart';
import 'package:syncare_flutter/features/auth/role_picker_screen.dart';
import 'package:syncare_flutter/widgets/disclaimer_banner.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    ValueChanged<AppRole>? onSelected,
    Map<String, Object> initialPrefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues(initialPrefs);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: RolePickerScreen(onSelected: onSelected ?? (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ProviderContainer containerOf(WidgetTester tester) {
    return ProviderScope.containerOf(
      tester.element(find.byType(RolePickerScreen)),
      listen: false,
    );
  }

  testWidgets(
    'renders brand, both roles, and the disclaimer banner at the top',
    (tester) async {
      await pumpScreen(tester);

      expect(find.text('SynCare'), findsOneWidget);
      expect(find.text('Saya Pasien'), findsOneWidget);
      expect(find.text('Saya Perawat'), findsOneWidget);
      expect(find.byType(DisclaimerBanner), findsOneWidget);

      final bannerTop = tester.getTopLeft(find.byType(DisclaimerBanner)).dy;
      final brandTop = tester.getTopLeft(find.text('SynCare')).dy;
      expect(bannerTop, lessThan(brandTop));
    },
  );

  testWidgets('prefills the demo patient ID from the provider default', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Pengaturan demo'), findsOneWidget);
    expect(find.text('ID Pasien demo'), findsOneWidget);
    expect(find.text(AppConfig.defaultPatientId), findsOneWidget);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, AppConfig.defaultPatientId);
  });

  testWidgets('tapping patient reports AppRole.patient and stores the role', (
    tester,
  ) async {
    AppRole? selected;
    await pumpScreen(tester, onSelected: (role) => selected = role);

    await tester.ensureVisible(find.text('Saya Pasien'));
    await tester.tap(find.text('Saya Pasien'));
    await tester.pumpAndSettle();

    expect(selected, AppRole.patient);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('role'), 'patient');
  });

  testWidgets('edited patient ID is persisted and reaches the provider', (
    tester,
  ) async {
    AppRole? selected;
    await pumpScreen(tester, onSelected: (role) => selected = role);

    await tester.ensureVisible(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'chf-chain-164858');
    await tester.pump();

    await tester.ensureVisible(find.text('Saya Pasien'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saya Pasien'));
    await tester.pumpAndSettle();

    expect(selected, AppRole.patient);
    expect(containerOf(tester).read(patientIdProvider), 'chf-chain-164858');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('patient_id'), 'chf-chain-164858');
    expect(prefs.getString('role'), 'patient');
  });

  testWidgets('hydrates a saved patient ID into the field', (tester) async {
    await pumpScreen(tester, initialPrefs: {'patient_id': 'chf-chain-164858'});

    expect(find.text('chf-chain-164858'), findsOneWidget);
  });

  testWidgets('tapping nurse reports AppRole.nurse and stores the role', (
    tester,
  ) async {
    AppRole? selected;
    await pumpScreen(tester, onSelected: (role) => selected = role);

    await tester.ensureVisible(find.text('Saya Perawat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saya Perawat'));
    await tester.pumpAndSettle();

    expect(selected, AppRole.nurse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('role'), 'nurse');
  });

  testWidgets('scrolls so both roles stay tappable on a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    AppRole? selected;
    await pumpScreen(tester, onSelected: (role) => selected = role);

    expect(find.text('Saya Pasien'), findsOneWidget);
    await tester.ensureVisible(find.text('Saya Perawat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saya Perawat'));
    await tester.pumpAndSettle();

    expect(selected, AppRole.nurse);
  });
}
