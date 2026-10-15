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

    test('shortDate shows LOCAL time and keeps non-ISO text', () {
      const iso = '2026-10-12T07:45:00.000Z';
      final l = DateTime.parse(iso).toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      final date = '${l.year}-${two(l.month)}-${two(l.day)}';
      expect(shortDate(iso), date);
      expect(shortDate(iso, time: true), '$date ${two(l.hour)}:${two(l.minute)}');
      expect(timeOnly(iso), '${two(l.hour)}:${two(l.minute)}');
      expect(shortDate('10:30 AM'), '10:30 AM');
      expect(shortDate(null), '');
      expect(parseIso('nope'), isNull);
      expect(parseIso(iso), isNotNull);
    });

    test('passwordPolicyError mirrors the backend policy', () {
      expect(passwordPolicyError('short1'), isNotNull); // < 10
      expect(passwordPolicyError('onlyletterspassword'), isNotNull); // no digit
      expect(passwordPolicyError('1234567890123'), isNotNull); // no letter
      expect(passwordPolicyError('Mypassword123'), isNotNull); // contains "password"
      expect(passwordPolicyError('Ludo-Supreme-77'), isNull); // dashes break the weak word, like the backend
      expect(passwordPolicyError('Tr1cky-Horse-Battery'), isNull);
      expect(passwordPolicyError('a' * 73 + '1'), isNotNull); // > 72
    });

    test('isMongoId accepts only 24 hex chars', () {
      expect(isMongoId('64b000000000000000000001'), isTrue);
      expect(isMongoId('64b0000000000000000000'), isFalse);
      expect(isMongoId('zzzzzzzzzzzzzzzzzzzzzzzz'), isFalse);
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
