import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_supreme_admin/theme.dart';
import 'package:ludo_supreme_admin/utils/safe.dart';

void main() {
  group('safe parsing helpers', () {
    test('asMap / asList never throw on wrong types', () {
      expect(asMap(null), isEmpty);
      expect(asMap([1, 2]), isEmpty);
      expect(asMap({1: 'a'})['1'], 'a');
      expect(asList('x'), isEmpty);
      expect(asList([1]), [1]);
    });

    test('asNum handles strings, null and NaN', () {
      expect(asNum('12.5'), 12.5);
      expect(asNum(null), 0);
      expect(asNum('abc', 7), 7);
      expect(asNum(double.nan), 0);
    });

    test('initialOf is safe for empty / null names', () {
      expect(initialOf(''), '?');
      expect(initialOf(null, 'U'), 'U');
      expect(initialOf('rahul'), 'R');
    });

    test('shortDate keeps non-ISO text and trims ISO', () {
      expect(shortDate('2026-10-12T07:45:00.000Z'), '2026-10-12');
      expect(shortDate('2026-10-12T07:45:00.000Z', time: true), '2026-10-12 07:45');
      expect(shortDate('10:30 AM'), '10:30 AM');
      expect(timeOnly('2026-10-12T07:45:00Z'), '07:45');
    });

    test('compactNum / pct / uptime formatting', () {
      expect(compactNum(500.0), '500');
      expect(compactNum(12500), '12.5k');
      expect(compactNum(1500000), '1.5M');
      expect(pct(12.345678), '12.3');
      expect(formatUptime(345600), '4d 0h');
      expect(formatUptime(0), '0m');
    });

    test('formatCurrency accepts any type', () {
      expect(formatCurrency(182650), '🪙 182,650');
      expect(formatCurrency('1200'), '🪙 1,200');
      expect(formatCurrency(null), '🪙 0');
      expect(formatCurrency(12.5), '🪙 12.50');
    });
  });
}
