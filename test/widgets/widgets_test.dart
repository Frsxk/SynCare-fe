import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncare_flutter/core/api_exception.dart';
import 'package:syncare_flutter/core/config.dart';
import 'package:syncare_flutter/core/providers.dart';
import 'package:syncare_flutter/core/theme.dart';
import 'package:syncare_flutter/widgets/disclaimer_banner.dart';
import 'package:syncare_flutter/widgets/empty_state.dart';
import 'package:syncare_flutter/widgets/error_state.dart';
import 'package:syncare_flutter/widgets/risk_badge.dart';
import 'package:syncare_flutter/widgets/source_chip.dart';
import 'package:syncare_flutter/widgets/token_dialog.dart';

import '../helpers/pump_app.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget widget, {
  List<Override> overrides = const <Override>[],
}) {
  return tester.pumpWidget(
    wrapScreen(Scaffold(body: widget), overrides: overrides),
  );
}

void main() {
  group('AppTheme', () {
    test('builds a light Material 3 theme with padded touch targets', () {
      final ThemeData theme = AppTheme.light();

      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.brightness, Brightness.light);
      expect(theme.materialTapTargetSize, MaterialTapTargetSize.padded);

      final Size? buttonSize = theme.filledButtonTheme.style?.minimumSize
          ?.resolve(const <WidgetState>{});
      expect(buttonSize, isNotNull);
      expect(buttonSize!.height, greaterThanOrEqualTo(48));
    });
  });

  group('RiskBadge', () {
    Future<void> pumpBadge(WidgetTester tester, String? tier) {
      return _pump(tester, Center(child: RiskBadge(tier: tier)));
    }

    testWidgets('renders each server tier verbatim', (
      WidgetTester tester,
    ) async {
      for (final String tier in <String>['LOW', 'MEDIUM', 'HIGH']) {
        await pumpBadge(tester, tier);
        expect(find.text(tier), findsOneWidget);
      }
    });

    testWidgets('HIGH uses the tinted high-risk surface', (
      WidgetTester tester,
    ) async {
      await pumpBadge(tester, 'HIGH');

      final Container container = tester.widget<Container>(
        find.descendant(
          of: find.byType(RiskBadge),
          matching: find.byType(Container),
        ),
      );
      final BoxDecoration decoration = container.decoration! as BoxDecoration;

      expect(decoration.color, AppTheme.highContainer);
    });

    testWidgets('null and unknown tiers show a neutral TIDAK DIKETAHUI chip', (
      WidgetTester tester,
    ) async {
      await pumpBadge(tester, null);
      expect(find.text('TIDAK DIKETAHUI'), findsOneWidget);

      await pumpBadge(tester, 'CRITICAL');
      expect(find.text('TIDAK DIKETAHUI'), findsOneWidget);
      expect(find.text('CRITICAL'), findsNothing);
    });
  });

  group('DisclaimerBanner', () {
    testWidgets('states this is a synthetic demo and not medical advice', (
      WidgetTester tester,
    ) async {
      await _pump(tester, const DisclaimerBanner());

      expect(find.byType(DisclaimerBanner), findsOneWidget);
      expect(find.textContaining('Demo sintetis'), findsOneWidget);
      expect(find.textContaining('bukan nasihat medis'), findsOneWidget);
      expect(find.byIcon(Icons.science_outlined), findsOneWidget);
    });
  });

  group('SourceChip', () {
    testWidgets('labels provenance and truncates to one line', (
      WidgetTester tester,
    ) async {
      const String source = 'patient:care_intensity:1#1 | f5_grounded_answer';
      await _pump(tester, const Center(child: SourceChip(source: source)));

      expect(find.text('Sumber: $source'), findsOneWidget);
      expect(find.byIcon(Icons.link_rounded), findsOneWidget);

      final Text label = tester.widget<Text>(find.text('Sumber: $source'));
      expect(label.maxLines, 1);
      expect(label.overflow, TextOverflow.ellipsis);
    });

    testWidgets('does not overflow in a narrow parent', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const Center(
          child: SizedBox(
            width: 160,
            child: SourceChip(
              source:
                  'patient:care_intensity:1#1 | patient:plan:approved | '
                  'patient:audit:approve:2026-10-23',
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('ErrorState', () {
    testWidgets('Unauthorized asks for a new token and calls onReauth', (
      WidgetTester tester,
    ) async {
      var reauthCalls = 0;

      await _pump(
        tester,
        ErrorState(
          error: const UnauthorizedException(),
          onReauth: () => reauthCalls++,
        ),
      );

      expect(find.text('Sesi tidak valid'), findsOneWidget);
      expect(find.text('Perbarui token'), findsOneWidget);
      expect(find.text('Coba lagi'), findsNothing);

      await tester.tap(find.text('Perbarui token'));
      expect(reauthCalls, 1);
    });

    testWidgets('ReadOnly has no retry affordance', (
      WidgetTester tester,
    ) async {
      var retryCalls = 0;

      await _pump(
        tester,
        ErrorState(
          error: const ReadOnlyException(),
          onRetry: () => retryCalls++,
        ),
      );

      expect(find.text('Server dalam mode baca-saja'), findsOneWidget);
      expect(find.text('Coba lagi'), findsNothing);
      expect(retryCalls, 0);
    });

    testWidgets('Validation shows the server message verbatim', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const ErrorState(
          error: ValidationException('followup_date wajib diisi.'),
        ),
      );

      expect(find.text('followup_date wajib diisi.'), findsOneWidget);
      expect(find.text('Permintaan tidak valid'), findsOneWidget);
    });

    testWidgets('ServerConfig shows the server message verbatim', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const ErrorState(
          error: ServerConfigException('SYNCARE_API_KEY belum diatur.'),
        ),
      );

      expect(find.text('SYNCARE_API_KEY belum diatur.'), findsOneWidget);
      expect(find.text('Konfigurasi server bermasalah'), findsOneWidget);
    });

    testWidgets('StreamUnavailable offers retry', (WidgetTester tester) async {
      var retryCalls = 0;

      await _pump(
        tester,
        ErrorState(
          error: const StreamUnavailableException(),
          onRetry: () => retryCalls++,
        ),
      );

      expect(find.text('Tidak bisa membuka aliran peristiwa'), findsOneWidget);
      await tester.tap(find.text('Coba lagi'));
      expect(retryCalls, 1);
    });

    testWidgets('EngineWarming explains the warming engine and retries', (
      WidgetTester tester,
    ) async {
      var retryCalls = 0;

      await _pump(
        tester,
        ErrorState(
          error: const EngineWarmingException(),
          onRetry: () => retryCalls++,
        ),
      );

      expect(find.text('Layanan sedang menyiapkan, coba lagi'), findsOneWidget);
      expect(find.text('Coba lagi'), findsOneWidget);

      await tester.tap(find.text('Coba lagi'));
      expect(retryCalls, 1);
    });

    testWidgets('Network offers retry', (WidgetTester tester) async {
      var retryCalls = 0;

      await _pump(
        tester,
        ErrorState(
          error: const NetworkException(),
          onRetry: () => retryCalls++,
        ),
      );

      expect(find.text('Tidak bisa menghubungi server'), findsOneWidget);
      await tester.tap(find.text('Coba lagi'));
      expect(retryCalls, 1);
    });

    testWidgets('NotFound explains the missing data', (
      WidgetTester tester,
    ) async {
      await _pump(tester, const ErrorState(error: NotFoundException()));

      expect(find.text('Data tidak ditemukan'), findsOneWidget);
    });

    testWidgets('unknown errors hide internals and show generic copy', (
      WidgetTester tester,
    ) async {
      var retryCalls = 0;

      await _pump(
        tester,
        ErrorState(
          error: StateError('stack detail that must not leak'),
          onRetry: () => retryCalls++,
        ),
      );

      expect(find.text('Terjadi kesalahan'), findsOneWidget);
      expect(find.textContaining('stack detail'), findsNothing);
      expect(find.textContaining('StateError'), findsNothing);

      await tester.tap(find.text('Coba lagi'));
      expect(retryCalls, 1);
    });

    testWidgets('UnexpectedApiException also uses generic copy', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const ErrorState(
          error: UnexpectedApiException('internal detail', statusCode: 500),
        ),
      );

      expect(find.text('Terjadi kesalahan'), findsOneWidget);
      expect(find.textContaining('internal detail'), findsNothing);
    });

    testWidgets('InvalidResponseException also uses generic copy', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const ErrorState(
          error: InvalidResponseException('raw payload that must not leak'),
        ),
      );

      expect(find.text('Terjadi kesalahan'), findsOneWidget);
      expect(find.textContaining('raw payload'), findsNothing);
    });
  });

  group('EmptyState', () {
    testWidgets('renders icon, title and message centered', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const EmptyState(
          title: 'Belum ada rencana',
          message: 'Rencana yang disetujui akan muncul di sini.',
          icon: Icons.description_outlined,
        ),
      );

      expect(find.byIcon(Icons.description_outlined), findsOneWidget);
      expect(find.text('Belum ada rencana'), findsOneWidget);
      expect(
        find.text('Rencana yang disetujui akan muncul di sini.'),
        findsOneWidget,
      );

      final Text title = tester.widget<Text>(find.text('Belum ada rencana'));
      final Text message = tester.widget<Text>(
        find.text('Rencana yang disetujui akan muncul di sini.'),
      );
      expect(title.textAlign, TextAlign.center);
      expect(message.textAlign, TextAlign.center);
    });

    testWidgets('falls back to a default icon', (WidgetTester tester) async {
      await _pump(
        tester,
        const EmptyState(title: 'Kosong', message: 'Belum ada data.'),
      );

      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    });
  });

  group('showTokenDialog', () {
    testWidgets('is empty, obscured, writes, and confirms the save', (
      WidgetTester tester,
    ) async {
      final _RecordingTokenSource source = _RecordingTokenSource();

      await tester.pumpWidget(
        wrapScreen(
          const _TokenDialogHost(),
          overrides: <Override>[tokenSourceProvider.overrideWithValue(source)],
        ),
      );

      await tester.tap(find.text('Buka token'));
      await tester.pumpAndSettle();

      expect(find.text('Perbarui token akses'), findsOneWidget);

      TextField field = tester.widget<TextField>(find.byType(TextField));
      expect(field.obscureText, isTrue);
      expect(field.controller?.text ?? '', isEmpty);

      await tester.tap(find.byTooltip('Tampilkan token'));
      await tester.pump();
      field = tester.widget<TextField>(find.byType(TextField));
      expect(field.obscureText, isFalse);

      await tester.enterText(find.byType(TextField), 'token-demo-baru');
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      expect(source.writes, <String>['token-demo-baru']);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Token disimpan'), findsOneWidget);
    });

    testWidgets('never pre-fills the stored token on reopen', (
      WidgetTester tester,
    ) async {
      final _RecordingTokenSource source = _RecordingTokenSource()
        ..stored = 'token-lama';

      await tester.pumpWidget(
        wrapScreen(
          const _TokenDialogHost(),
          overrides: <Override>[tokenSourceProvider.overrideWithValue(source)],
        ),
      );

      await tester.tap(find.text('Buka token'));
      await tester.pumpAndSettle();

      final TextField field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text ?? '', isEmpty);
      expect(find.text('token-lama'), findsNothing);
    });

    testWidgets('Cancel closes without writing', (WidgetTester tester) async {
      final _RecordingTokenSource source = _RecordingTokenSource();

      await tester.pumpWidget(
        wrapScreen(
          const _TokenDialogHost(),
          overrides: <Override>[tokenSourceProvider.overrideWithValue(source)],
        ),
      );

      await tester.tap(find.text('Buka token'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'tidak-jadi-disimpan');
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(source.writes, isEmpty);
    });

    testWidgets('rejects an empty token without writing', (
      WidgetTester tester,
    ) async {
      final _RecordingTokenSource source = _RecordingTokenSource();

      await tester.pumpWidget(
        wrapScreen(
          const _TokenDialogHost(),
          overrides: <Override>[tokenSourceProvider.overrideWithValue(source)],
        ),
      );

      await tester.tap(find.text('Buka token'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      expect(find.text('Token tidak boleh kosong.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(source.writes, isEmpty);
    });
  });
}

class _TokenDialogHost extends ConsumerWidget {
  const _TokenDialogHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () => showTokenDialog(context, ref),
          child: const Text('Buka token'),
        ),
      ),
    );
  }
}

class _RecordingTokenSource implements TokenSource {
  final List<String> writes = <String>[];
  String? stored;

  @override
  Future<String?> read() async => stored;

  @override
  Future<void> write(String token) async {
    stored = token;
    writes.add(token);
  }

  @override
  Future<void> clear() async {
    stored = null;
  }
}
