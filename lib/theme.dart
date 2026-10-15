import 'package:flutter/material.dart';
import 'utils/safe.dart';

const kNavy = Color(0xFF0B1F5C);
const kBlue = Color(0xFF1677FF);
const kBg = Color(0xFFF4F7FC);
const kGreen = Color(0xFF22B358);
const kPurple = Color(0xFF7C4DFF);
const kOrange = Color(0xFFFFA000);
const kRed = Color(0xFFE53935);

ThemeData appTheme() => ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: kBg,
      colorScheme: ColorScheme.fromSeed(seedColor: kBlue),
      fontFamily: 'Roboto',
    );

Widget card(String title, Widget child, {Widget? trailing}) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6ECF5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
          if (trailing != null) trailing,
        ]),
        const SizedBox(height: 12),
        child,
      ]),
    );

Widget statusChip(String s) {
  final l = s.toLowerCase();
  Color c = kBlue;
  if (l == 'active' || l == 'completed' || l == 'online' || l == 'resolved' || l == 'won' || l == 'win') {
    c = kGreen;
  } else if (l == 'blocked' ||
      l == 'abandoned' ||
      l == 'closed' ||
      l == 'offline' ||
      l == 'inactive' ||
      l == 'high' ||
      l == 'surrendered' ||
      l == 'loss' ||
      l == 'expired' ||
      l == 'lost') {
    c = kRed;
  } else if (l == 'in_progress' || l == 'pending' || l == 'open' || l == 'draw') {
    c = kOrange;
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: c.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      s,
      style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );
}

String _group(String digits) {
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return buf.toString();
}

/// Kisi bhi type (num / String / null) ko safely "🪙 12,345" me badalta hai.
String formatCurrency(dynamic amount) {
  final n = asNum(amount);
  final neg = n < 0;
  final a = n.abs();
  final whole = a.truncateToDouble() == a.toDouble();
  final parts = a.toStringAsFixed(whole ? 0 : 2).split('.');
  final grouped = _group(parts[0]) + (parts.length > 1 ? '.${parts[1]}' : '');
  return '🪙 ${neg ? '-' : ''}$grouped';
}
