/// Asia/Jakarta (WIB) is a fixed UTC+7 offset without daylight saving.
const Duration _wibOffset = Duration(hours: 7);

/// Explicit ISO-8601 instant with seconds and a mandatory `Z` or `±HH:MM`
/// zone. A zone-less value has no defined instant, so it is refused.
final RegExp _instant = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})'
  r'(?:\.\d{1,6})?(Z|[+-](\d{2}):(\d{2}))$',
);

/// Formats an explicit ISO-8601 instant as the app's `YYYY-MM-DD HH:MM WIB`
/// label, matching booking and approval timestamps.
///
/// Returns `null` for missing, zone-less, calendar-invalid, or unparseable
/// input. It never substitutes the epoch or the current time, and converting
/// the parsed instant through UTC prevents double conversion of an already
/// offset value.
String? wibLabel(Object? value) {
  if (value is! String) {
    return null;
  }
  final match = _instant.firstMatch(value.trim());
  if (match == null) {
    return null;
  }
  final year = int.parse(match[1]!),
      month = int.parse(match[2]!),
      day = int.parse(match[3]!),
      hour = int.parse(match[4]!),
      minute = int.parse(match[5]!),
      second = int.parse(match[6]!);
  if (month < 1 ||
      month > 12 ||
      day < 1 ||
      day > _daysInMonth(year, month) ||
      hour > 23 ||
      minute > 59 ||
      second > 59) {
    return null;
  }
  var offset = Duration.zero;
  final zone = match[7]!;
  if (zone != 'Z') {
    final offsetHour = int.parse(match[8]!),
        offsetMinute = int.parse(match[9]!);
    if (offsetHour > 23 || offsetMinute > 59) {
      return null;
    }
    final magnitude = offsetHour * 60 + offsetMinute;
    offset = Duration(minutes: zone.startsWith('-') ? -magnitude : magnitude);
  }
  final instant = DateTime.utc(
    year,
    month,
    day,
    hour,
    minute,
    second,
  ).subtract(offset).add(_wibOffset);
  final text = instant.toIso8601String();
  return '${text.substring(0, 10)} ${text.substring(11, 16)} WIB';
}

int _daysInMonth(int year, int month) {
  const days = <int>[31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  final leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
  return month == 2 && leap ? 29 : days[month - 1];
}
