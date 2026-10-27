import 'package:flutter_test/flutter_test.dart';
import 'package:syncare_flutter/core/wib_time.dart';

void main() {
  test('UTC and offset instants become WIB labels without double conversion', () {
    expect(wibLabel('2026-10-25T00:00:00Z'), '2026-10-25 07:00 WIB');
    expect(wibLabel('2026-10-25T00:00:00.123Z'), '2026-10-25 07:00 WIB');
    expect(wibLabel('2026-10-25T18:30:00Z'), '2026-10-26 01:30 WIB');
    expect(wibLabel('2026-10-25T07:00:00+07:00'), '2026-10-25 07:00 WIB');
    expect(wibLabel('2026-10-25T20:00:00+02:00'), '2026-10-26 01:00 WIB');
    expect(wibLabel('2026-10-25T01:30:00+05:30'), '2026-10-25 03:00 WIB');
  });

  test('invalid or zone-less values return null, never epoch or current time', () {
    for (final Object? value in <Object?>[
      null,
      '',
      '   ',
      'not-a-date',
      '2026-10-25',
      '2026-13-01T00:00:00Z',
      '2026-10-25T00:00:00',
      123,
    ]) {
      expect(wibLabel(value), isNull, reason: 'input: $value');
    }
  });
}
