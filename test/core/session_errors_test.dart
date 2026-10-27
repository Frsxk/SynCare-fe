import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncare_flutter/core/api_exception.dart';
import 'package:syncare_flutter/widgets/error_state.dart';

void main() {
  test(
    'domain permission denial is distinct from the legacy read-only response',
    () {
      expect(
        apiExceptionForStatus(
          403,
          jsonEncode({
            'error': {'code': 'forbidden', 'message': 'private detail'},
          }),
        ),
        isA<ForbiddenException>(),
      );
      expect(
        apiExceptionForStatus(403, jsonEncode({'error': 'read_only_mode'})),
        isA<ReadOnlyException>(),
      );
    },
  );
  testWidgets(
    'expired session offers sign-in, never a manual patient token',
    (tester) async {
      var reauthCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorState(
              error: const UnauthorizedException(),
              onReauth: () => reauthCalls++,
            ),
          ),
        ),
      );
      expect(find.text('Masuk kembali'), findsOneWidget);
      expect(find.text('Perbarui token'), findsNothing);
      expect(find.textContaining('Token akses'), findsNothing);
      await tester.tap(find.text('Masuk kembali'));
      expect(reauthCalls, 1);
    },
  );
  testWidgets(
    'permission denial renders a specific next step without a misleading read-only or token claim',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ErrorState(error: ForbiddenException())),
        ),
      );
      expect(find.text('Akses tidak diizinkan'), findsOneWidget);
      expect(
        find.textContaining('Hubungi perawat atau operator.'),
        findsOneWidget,
      );
      expect(find.text('Server dalam mode baca-saja'), findsNothing);
      expect(find.text('Perbarui token'), findsNothing);
    },
  );
}
