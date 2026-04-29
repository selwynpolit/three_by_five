import 'package:jiffy/jiffy.dart';
import 'package:intl/intl.dart';

/// Parses shorthand date strings ("2d", "3w", "1m") and natural-language
/// phrases ("today", "tomorrow") into DateTime values.
class DateParsingService {
  static final _shorthand = RegExp(
    r'^(\d+)\s*(d|w|m|y)$',
    caseSensitive: false,
  );

  /// Returns a DateTime relative to [from] (defaults to now), or null if
  /// the input is not recognised.
  DateTime? parse(String input, {DateTime? from}) {
    final base = from ?? DateTime.now();
    final s = input.trim().toLowerCase();

    // ── Shorthand: 2d, 3w, 1m, 1y ──────────────────────────────────────────
    final match = _shorthand.firstMatch(s);
    if (match != null) {
      final n = int.parse(match.group(1)!);
      final unit = match.group(2)!;
      final j = Jiffy.parseFromDateTime(base);
      return switch (unit) {
        'd' => j.add(days: n).dateTime,
        'w' => j.add(weeks: n).dateTime,
        'm' => j.add(months: n).dateTime,
        'y' => j.add(years: n).dateTime,
        _ => null,
      };
    }

    // ── Natural language ────────────────────────────────────────────────────
    return switch (s) {
      'today' => _dateOnly(base),
      'tomorrow' => _dateOnly(base.add(const Duration(days: 1))),
      'this friday' || 'friday' => _nextWeekday(base, DateTime.friday),
      'next monday' || 'monday' => _nextWeekday(base, DateTime.monday),
      'next tuesday' || 'tuesday' => _nextWeekday(base, DateTime.tuesday),
      'next wednesday' || 'wednesday' => _nextWeekday(base, DateTime.wednesday),
      'next thursday' || 'thursday' => _nextWeekday(base, DateTime.thursday),
      'next saturday' || 'saturday' => _nextWeekday(base, DateTime.saturday),
      'next sunday' || 'sunday' => _nextWeekday(base, DateTime.sunday),
      '1 week' => Jiffy.parseFromDateTime(base).add(weeks: 1).dateTime,
      '2 weeks' => Jiffy.parseFromDateTime(base).add(weeks: 2).dateTime,
      '1 month' => Jiffy.parseFromDateTime(base).add(months: 1).dateTime,
      '3 months' => Jiffy.parseFromDateTime(base).add(months: 3).dateTime,
      _ => null,
    };
  }

  /// Returns a human-readable confirmation, e.g. "3w → Mon 19 May".
  String? formatConfirmation(String input, {DateTime? from}) {
    final date = parse(input, from: from);
    if (date == null) return null;
    final formatted = DateFormat('EEE d MMM').format(date);
    return '$input → $formatted';
  }

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  DateTime _nextWeekday(DateTime from, int weekday) {
    var d = from.add(const Duration(days: 1));
    while (d.weekday != weekday) {
      d = d.add(const Duration(days: 1));
    }
    return _dateOnly(d);
  }
}
