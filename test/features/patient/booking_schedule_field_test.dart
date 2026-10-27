import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncare_flutter/features/patient/booking_schedule_field.dart';
import 'package:syncare_flutter/models/homecare.dart';
import '../../helpers/pump_app.dart';

void main() {
  testWidgets(
    'calendar selects a date without text input; cancel retains draft',
    (tester) async {
      final controller = TextEditingController(text: '2030-01-02');
      addTearDown(controller.dispose);
      final changes = <String>[];
      await tester.pumpWidget(
        wrapScreen(
          Scaffold(
            body: BookingScheduleField(
              label: 'Tanggal kunjungan',
              controller: controller,
              isDate: true,
              enabled: true,
              onChanged: changes.add,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Tanggal kunjungan'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DatePickerDialog>(find.byType(DatePickerDialog))
            .initialEntryMode,
        DatePickerEntryMode.calendarOnly,
      );
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('3').last);
      await tester.tap(find.text('Pilih tanggal'));
      await tester.pumpAndSettle();
      expect(controller.text, '2030-01-03');
      expect(changes, ['2030-01-03']);
      expect(find.text('03/01/2030'), findsOneWidget);
      await tester.tap(find.text('Tanggal kunjungan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('4').last);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(controller.text, '2030-01-03');
      expect(changes.length, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '24-hour clock selects time, keeps WIB conversion, and cannot type',
    (tester) async {
      final controller = TextEditingController(text: '08:15');
      addTearDown(controller.dispose);
      final changes = <String>[];
      await tester.pumpWidget(
        wrapScreen(
          Scaffold(
            body: BookingScheduleField(
              label: 'Jam mulai (WIB)',
              controller: controller,
              isDate: false,
              enabled: true,
              onChanged: changes.add,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Jam mulai (WIB)'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TimePickerDialog>(find.byType(TimePickerDialog))
            .initialEntryMode,
        TimePickerEntryMode.dialOnly,
      );
      expect(find.byType(TextField), findsNothing);
      final dial = find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint &&
            widget.painter.runtimeType.toString() == '_DialPainter',
      );
      final center = tester.getCenter(dial),
          radius = tester.getSize(dial).shortestSide * 0.4;
      await tester.tapAt(center + Offset(-0.866 * radius, -0.5 * radius));
      await tester.pumpAndSettle();
      await tester.tapAt(center + Offset(0, radius));
      await tester.tap(find.text('Pilih jam'));
      await tester.pumpAndSettle();
      expect(controller.text, '10:30');
      expect(changes, ['10:30']);
      final input = BookingInput.fromFields('service', {
        'date': '2030-01-03',
        'start': controller.text,
        'end': '11:30',
        'address': 'Alamat sintetis',
        'kelurahan': 'Wilayah',
        'kecamatan': 'Wilayah',
        'city': 'Jakarta Pusat',
      });
      expect(input.startAt, '2030-01-03T03:30:00.000Z');
      await tester.tap(find.text('Jam mulai (WIB)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(changes.length, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('disabled field cannot open a picker at320 text200', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final controller = TextEditingController(text: '09:00');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      wrapScreen(
        Scaffold(
          body: BookingScheduleField(
            label: 'Jam selesai (WIB)',
            controller: controller,
            isDate: false,
            enabled: false,
            onChanged: (_) => fail('disabled picker changed draft'),
          ),
        ),
      ),
    );
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    expect(find.byType(TimePickerDialog), findsNothing);
    expect(find.text('09:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
