import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncare_flutter/core/theme.dart';
import 'package:syncare_flutter/features/patient/risk_summary.dart';
import 'package:syncare_flutter/widgets/risk_badge.dart';
import '../../helpers/patient_fixture.dart';

void main() {
  testWidgets(
    'risk_summary_redflag_independent: confirmed LOW and server urgent message remain separate',
    (tester) async {
      final risk = overviewFixture(status: 'confirmed').confirmedRisk;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: RiskSummary(
                risk: risk,
                urgentReason: 'Pesan mendesak dari server',
              ),
            ),
          ),
        ),
      );
      expect(tester.widget<RiskBadge>(find.byType(RiskBadge)).tier, 'LOW');
      expect(
        find.text('Peringatan mendesak: Pesan mendesak dari server'),
        findsOneWidget,
      );
      expect(find.text('Kategori dikonfirmasi perawat'), findsOneWidget);
      expect(find.byType(ExpansionTile), findsNothing);
      expect(find.text('Skor F1: 0. Sumber versi 1.'), findsNothing);
      expect(find.text('Detail penilaian'), findsNothing);
    },
  );
  testWidgets(
    'new source labels old category historical without a current risk badge',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RiskSummary(
              risk: overviewFixture(
                status: 'needs_reassessment',
                category: 'HIGH',
              ).confirmedRisk,
            ),
          ),
        ),
      );
      expect(
        find.textContaining('Perlu penilaian dan konfirmasi ulang'),
        findsOneWidget,
      );
      expect(find.textContaining('Kategori sebelumnya: HIGH'), findsNothing);
      expect(find.byType(RiskBadge), findsNothing);
      expect(find.text('Detail penilaian'), findsNothing);
    },
  );
  testWidgets(
    'missing confirmation does not substitute the latest proposed HIGH',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RiskSummary(risk: overviewFixture().confirmedRisk),
          ),
        ),
      );
      expect(find.textContaining('Belum ada kategori risiko'), findsOneWidget);
      expect(find.text('HIGH'), findsNothing);
    },
  );
}
