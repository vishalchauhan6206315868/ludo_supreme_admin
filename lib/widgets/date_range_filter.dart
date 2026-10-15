import 'package:flutter/material.dart';

/// Date range chunne ka chhota button (+ clear). Backend ke `from` / `to` filters ke liye.
class DateRangeFilter extends StatelessWidget {
  const DateRangeFilter({super.key, required this.value, required this.onChanged});

  final DateTimeRange? value;
  final ValueChanged<DateTimeRange?> onChanged;

  static String _d(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final label = value == null ? 'All dates' : '${_d(value!.start)} to ${_d(value!.end)}';
    return Row(mainAxisSize: MainAxisSize.min, children: [
      OutlinedButton.icon(
        onPressed: () async {
          final now = DateTime.now();
          final picked = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: DateTime(now.year + 1, 12, 31),
            initialDateRange: value,
          );
          if (picked != null) onChanged(picked);
        },
        icon: const Icon(Icons.date_range, size: 18),
        label: Text(label),
      ),
      if (value != null)
        IconButton(
          tooltip: 'Clear dates',
          icon: const Icon(Icons.close, size: 18),
          onPressed: () => onChanged(null),
        ),
    ]);
  }
}

/// DateTimeRange -> backend query (`from` din ki shuruaat, `to` din ka end; local day -> UTC ISO).
Map<String, String> rangeQuery(DateTimeRange? r) {
  if (r == null) return {};
  final from = DateTime(r.start.year, r.start.month, r.start.day);
  final to = DateTime(r.end.year, r.end.month, r.end.day, 23, 59, 59, 999);
  return {'from': from.toUtc().toIso8601String(), 'to': to.toUtc().toIso8601String()};
}
