import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncare_flutter/features/patient/checkin_providers.dart';
import 'package:syncare_flutter/features/patient/checkin_screen.dart';
import 'package:syncare_flutter/features/patient/checkin_detail_screen.dart';
import 'package:syncare_flutter/features/patient/home_screen.dart';
import 'package:syncare_flutter/features/patient/homecare_screen.dart';
import 'package:syncare_flutter/models/homecare.dart';
import 'package:syncare_flutter/widgets/patient_details.dart';

import '../../helpers/fakes.dart';
import '../../helpers/homecare_fixture.dart';
import '../../helpers/checkin_fixture.dart';
import '../../helpers/patient_fixture.dart';
import '../../helpers/pump_app.dart';

void narrowLargeText(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 800);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

void main() {
  testWidgets(
    'patient overview and report omit backend identifiers and score explanations',
    (tester) async {
      narrowLargeText(tester);
      await tester.pumpWidget(
        wrapScreen(
          Scaffold(
            body: SingleChildScrollView(
              child: OverviewContent(
                overview: overviewFixture(status: 'confirmed'),
                onRefresh: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Detail akun'), findsNothing);
      expect(find.textContaining('ID pasien:'), findsNothing);
      expect(find.text('Kategori dikonfirmasi perawat'), findsOneWidget);
      await tester.pumpWidget(
        wrapScreen(
          Scaffold(
            body: SingleChildScrollView(
              child: CheckinEvidence(record: checkinFixture()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Data sintetis khusus unit test.'), findsOneWidget);
      expect(find.text('Interval check-in demo: 7 hari.'), findsOneWidget);
      for (final diagnostic in [
        'ID laporan:',
        'Skor F2:',
        'Baseline asli',
        'Diterapkan:',
        'assessment-a',
        'Detail hasil',
      ]) {
        expect(find.textContaining(diagnostic), findsNothing);
      }
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'patient details preserve complete evidence behind a keyboard-operable disclosure at320 text200',
    (tester) async {
      narrowLargeText(tester);
      const evidence =
          'Identitas lengkap: abcdef01-2345-6789-abcd-0123456789ab';
      await tester.pumpWidget(
        wrapScreen(
          const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsetsDirectional.all(24),
              child: PatientDetails(
                title: 'Detail laporan',
                children: [Text(evidence)],
              ),
            ),
          ),
        ),
      );
      expect(find.text(evidence), findsNothing);
      final semantics = tester.ensureSemantics();
      expect(
        tester
            .getSemantics(find.text('Detail laporan'))
            .flagsCollection
            .isButton,
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text(evidence), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text(evidence), findsNothing);
      semantics.dispose();
    },
  );

  testWidgets(
    'check-in has a separated primary action and concise form with unchanged input limit at320 text200',
    (tester) async {
      narrowLargeText(tester);
      await tester.pumpWidget(
        wrapScreen(
          const PatientCheckinScreen(),
          overrides: [
            checkinSubmitProvider.overrideWith(
              (_) => CheckinSubmitController(FakeSyncareApi(), 'patient-a'),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final field = find.byType(TextField);
      final submit = find.widgetWithText(FilledButton, 'Kirim check-in');
      expect(tester.widget<TextField>(field).maxLength, 8000);
      expect(tester.widget<TextField>(field).decoration!.counterText, '');
      await tester.ensureVisible(submit);
      expect(
        tester.getTopLeft(submit).dy - tester.getBottomLeft(field).dy,
        greaterThanOrEqualTo(24),
      );
      expect(
        find.textContaining('status tersimpan muncul setelah server'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'homecare service remains separate from refresh and complete description expands at320 text200',
    (tester) async {
      narrowLargeText(tester);
      await tester.pumpWidget(
        wrapScreen(
          Scaffold(
            body: HomecareCatalogList(
              page: const ServicePage([demoService], null),
              onRefresh: () {},
              onNext: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(demoService.description), findsNothing);
      final refresh = find.widgetWithText(OutlinedButton, 'Muat ulang katalog');
      await tester.scrollUntilVisible(refresh, 250);
      final card = find.ancestor(
        of: find.text(demoService.name),
        matching: find.byType(Card),
      );
      expect(
        tester.getTopLeft(refresh).dy - tester.getBottomLeft(card).dy,
        greaterThanOrEqualTo(16),
      );
      await tester.ensureVisible(find.text('Detail layanan'));
      await tester.tap(find.text('Detail layanan'));
      await tester.pumpAndSettle();
      expect(find.text(demoService.description), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
