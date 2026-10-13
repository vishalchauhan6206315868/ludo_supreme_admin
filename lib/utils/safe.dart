import 'dart:async';
import 'package:flutter/foundation.dart';

/// Safe-parsing helpers: backend ka response kisi bhi shape me aaye,
/// UI crash nahi hona chahiye.

Map<String, dynamic> asMap(dynamic v) {
  if (v is Map) {
    return v.map((k, val) => MapEntry('$k', val));
  }
  return <String, dynamic>{};
}

List<dynamic> asList(dynamic v) => v is List ? v : const <dynamic>[];

num asNum(dynamic v, [num fallback = 0]) {
  if (v is num) return v.isNaN || v.isInfinite ? fallback : v;
  return num.tryParse('$v') ?? fallback;
}

String asStr(dynamic v, [String fallback = '']) => v == null ? fallback : '$v';

/// Pehla visible character (empty/null par fallback).
String initialOf(dynamic v, [String fallback = '?']) {
  if (v == null) return fallback;
  final s = '$v'.trim();
  if (s.isEmpty) return fallback;
  return String.fromCharCode(s.runes.first).toUpperCase();
}

final RegExp _isoRe = RegExp(r'^(\d{4}-\d{2}-\d{2})[T ](\d{2}:\d{2})');

/// ISO date ko "YYYY-MM-DD" (ya time=true par "YYYY-MM-DD HH:mm") banata hai.
/// Non-ISO text (jaise "10:30 AM") ko jaisa hai waisa hi chhodta hai.
String shortDate(dynamic v, {bool time = false}) {
  if (v == null) return '';
  final s = '$v'.trim();
  final m = _isoRe.firstMatch(s);
  if (m == null) return s;
  return time ? '${m.group(1)} ${m.group(2)}' : m.group(1)!;
}

String _trim1(num n) {
  final s = n.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

/// 12500 -> 12.5k, 1500000 -> 1.5M, 500.0 -> 500
String compactNum(num n) {
  final a = n.abs();
  if (a >= 1000000) return '${_trim1(n / 1000000)}M';
  if (a >= 1000) return '${_trim1(n / 1000)}k';
  return _trim1(n);
}

/// Percent text: 12.345678 -> "12.3"
String pct(num n) => _trim1(n.abs());

String formatUptime(num seconds) {
  final s = seconds.toInt();
  if (s <= 0) return '0m';
  final d = s ~/ 86400;
  final h = (s % 86400) ~/ 3600;
  final m = (s % 3600) ~/ 60;
  if (d > 0) return '${d}d ${h}h';
  if (h > 0) return '${h}h ${m}m';
  return '${m}m';
}

/// Search box ke liye: har keystroke par API call nahi.
class Debouncer {
  Debouncer([this.delay = const Duration(milliseconds: 450)]);
  final Duration delay;
  Timer? _timer;

  void run(VoidCallback fn) {
    _timer?.cancel();
    _timer = Timer(delay, fn);
  }

  void dispose() => _timer?.cancel();
}

/// ISO timestamp se sirf "HH:mm"; non-ISO text jaisa hai waisa.
String timeOnly(dynamic v) {
  if (v == null) return '';
  final s = '$v'.trim();
  final m = _isoRe.firstMatch(s);
  return m == null ? s : m.group(2)!;
}
