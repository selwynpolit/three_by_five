import 'package:flutter_test/flutter_test.dart';
import 'package:three_by_five/domain/services/date_parsing_service.dart';

void main() {
  // Fixed base: Wednesday 3 Jan 2024
  final base = DateTime(2024, 1, 3);
  final service = DateParsingService();

  DateTime? parse(String input) => service.parse(input, from: base);
  DateTime date(int y, int m, int d) => DateTime(y, m, d);

  group('DateParsingService — shorthand', () {
    test('1d adds one day', () {
      expect(parse('1d'), date(2024, 1, 4));
    });

    test('2d adds two days', () {
      expect(parse('2d'), date(2024, 1, 5));
    });

    test('1w adds one week', () {
      expect(parse('1w'), date(2024, 1, 10));
    });

    test('3w adds three weeks', () {
      expect(parse('3w'), date(2024, 1, 24));
    });

    test('1m adds one month', () {
      expect(parse('1m'), date(2024, 2, 3));
    });

    test('3m adds three months', () {
      expect(parse('3m'), date(2024, 4, 3));
    });

    test('1y adds one year', () {
      expect(parse('1y'), date(2025, 1, 3));
    });

    test('shorthand is case-insensitive', () {
      expect(parse('2D'), date(2024, 1, 5));
      expect(parse('1W'), date(2024, 1, 10));
      expect(parse('1M'), date(2024, 2, 3));
    });

    test('shorthand tolerates surrounding spaces', () {
      expect(parse('  2d  '), date(2024, 1, 5));
    });
  });

  group('DateParsingService — natural language', () {
    test('today returns base date only', () {
      expect(parse('today'), date(2024, 1, 3));
    });

    test('tomorrow returns next day', () {
      expect(parse('tomorrow'), date(2024, 1, 4));
    });

    test('friday finds next Friday (2 days ahead from Wednesday)', () {
      expect(parse('friday'), date(2024, 1, 5));
    });

    test('"this friday" is same as "friday"', () {
      expect(parse('this friday'), date(2024, 1, 5));
    });

    test('thursday finds next Thursday (1 day ahead)', () {
      expect(parse('thursday'), date(2024, 1, 4));
    });

    test('monday finds next Monday (5 days ahead)', () {
      expect(parse('monday'), date(2024, 1, 8));
    });

    test('"next monday" is same as "monday"', () {
      expect(parse('next monday'), date(2024, 1, 8));
    });

    test('saturday skips forward correctly', () {
      expect(parse('saturday'), date(2024, 1, 6));
    });

    test('sunday skips forward correctly', () {
      expect(parse('sunday'), date(2024, 1, 7));
    });

    test('wednesday finds the NEXT wednesday, not today', () {
      // Base is Wednesday — nextWeekday starts from tomorrow, so finds next Wed
      expect(parse('wednesday'), date(2024, 1, 10));
    });

    test('1 week adds 7 days', () {
      expect(parse('1 week'), date(2024, 1, 10));
    });

    test('2 weeks adds 14 days', () {
      expect(parse('2 weeks'), date(2024, 1, 17));
    });

    test('1 month adds one month', () {
      expect(parse('1 month'), date(2024, 2, 3));
    });

    test('3 months adds three months', () {
      expect(parse('3 months'), date(2024, 4, 3));
    });
  });

  group('DateParsingService — invalid input', () {
    test('unrecognised string returns null', () {
      expect(parse('next year'), isNull);
      expect(parse('asap'), isNull);
      expect(parse(''), isNull);
    });
  });

  group('DateParsingService — formatConfirmation', () {
    test('returns formatted string for valid input', () {
      final result = service.formatConfirmation('2d', from: base);
      // Jan 5 2024 is a Friday
      expect(result, '2d → Fri 5 Jan');
    });

    test('returns null for invalid input', () {
      expect(service.formatConfirmation('asap', from: base), isNull);
    });
  });
}
