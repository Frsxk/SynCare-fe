import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncare_flutter/core/api_exception.dart';
import 'package:syncare_flutter/core/theme.dart';
import 'package:syncare_flutter/features/patient/checkin_providers.dart';
import 'package:syncare_flutter/features/patient/emergency_notice.dart';
import 'package:syncare_flutter/features/patient/checkin_detail_screen.dart';
import 'package:syncare_flutter/models/checkin_record.dart';
import '../../helpers/checkin_fixture.dart';
import '../../helpers/pump_app.dart';

void main() {
  test('urgent theme text and recovery control meet normal-text contrast', () {
    final theme = AppTheme.light();
    final colors = theme.colorScheme;
    double contrast(Color a, Color b) {
      final x = a.computeLuminance(), y = b.computeLuminance();
      return ((x > y ? x : y) + 0.05) / ((x > y ? y : x) + 0.05);
    }

    expect(
      contrast(colors.onErrorContainer, colors.errorContainer),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(
        theme.outlinedButtonTheme.style!.foregroundColor!.resolve({})!,
        colors.errorContainer,
      ),
      greaterThanOrEqualTo(4.5),
    );
  });
  testWidgets(
    'trigger_plan_review is an F2 review indication, without acute warning or a confirmed-risk claim',
    (tester) async {
      final json = checkinJson();
      (json['outcome'] as Map<String, Object>).addAll(<String, Object>{
        'action': 'trigger_plan_review',
        'tier_changed': true,
        'tier': 'HIGH',
        'score': 4,
      });
      await tester.pumpWidget(
        wrapScreen(
          Scaffold(
            body: SingleChildScrollView(
              child: CheckinEvidence(record: CheckinRecord.fromJson(json)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Perlu tinjauan rencana oleh perawat.'), findsOneWidget);
      expect(find.byType(EmergencyNotice), findsNothing);
      expect(find.text('Rincian laporan'), findsNothing);
      expect(find.textContaining('Skor F2:'), findsNothing);
      expect(find.textContaining('assessment-a'), findsNothing);
    },
  );
  testWidgets(
    'urgent_without_ack: known reason still warns if guidance/alert storage unavailable, no phone fallback or wait instruction',
    (tester) async {
      await tester.pumpWidget(
        wrapScreen(
          const Scaffold(
            body: EmergencyNotice(
              reason: 'F2 synthetic reason',
              alertEvidence: 'unavailable',
            ),
          ),
          overrides: [
            emergencyGuidanceProvider.overrideWith(
              (_) => throw const NetworkException(),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('F2 synthetic reason'), findsOneWidget);
      expect(
        find.textContaining('Kontak darurat terverifikasi belum tersedia'),
        findsOneWidget,
      );
      expect(find.textContaining('119'), findsNothing);
      expect(
        find.textContaining('Jangan menunggu balasan aplikasi'),
        findsOneWidget,
      );
      final live = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .any((s) => s.properties.liveRegion == true);
      expect(live, isTrue);
    },
  );
  testWidgets(
    'verified 119 is information only, with provenance and no telephone action',
    (tester) async {
      await tester.pumpWidget(
        wrapScreen(
          const Scaffold(
            body: SingleChildScrollView(
              child: EmergencyNotice(
                reason: 'F2 synthetic reason',
                alertEvidence: 'queued',
              ),
            ),
          ),
          overrides: [
            emergencyGuidanceProvider.overrideWith(
              (_) async => guidanceFixture,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('119'), findsOneWidget);
      expect(
        find.textContaining('Aplikasi tidak melakukan panggilan'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Aplikasi tidak mengirim bantuan'),
        findsOneWidget,
      );
      expect(find.byType(FilledButton), findsNothing);
    },
  );
}
