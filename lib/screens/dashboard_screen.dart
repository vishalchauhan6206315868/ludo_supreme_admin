import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../utils/safe.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _data; // last good response
  String? _error;
  bool _loading = true;
  bool _refreshing = false;
  DateTime? _updatedAt;
  int _req = 0; // stale response guard

  static const modeColors = [kBlue, kGreen, kPurple, kOrange, Color(0xFF00BCD4)];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool fresh = false}) async {
    final req = ++_req;
    setState(() {
      _loading = true;
      _refreshing = fresh;
      _error = null;
    });
    try {
      final res = await ApiService.get('/admin/dashboard', query: fresh ? {'refresh': '1'} : null);
      if (!mounted || req != _req) return;
      final root = asMap(res);
      final d = root['data'] is Map ? asMap(root['data']) : root;
      if (res is! Map || d.isEmpty) {
        throw ApiException('Invalid response format from server');
      }
      setState(() {
        _data = d;
        _updatedAt = DateTime.now();
      });
    } catch (e) {
      if (!mounted || req != _req) return;
      setState(() => _error = '$e');
    } finally {
      // Hamesha reset hota hai (pehle _refreshing kabhi false nahi hota tha).
      if (mounted && req == _req) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  // ------------------------------------------------------------ helpers
  double _niceInterval(double maxV) {
    if (maxV <= 0) return 1;
    final raw = maxV / 4;
    final k = (math.log(raw) / math.ln10).floor();
    final mag = math.pow(10, k).toDouble();
    final norm = raw / mag;
    final nice = norm <= 1 ? 1 : (norm <= 2 ? 2 : (norm <= 5 ? 5 : 10));
    return nice * mag;
  }

  double _axisMax(double maxV, double interval) {
    var m = (maxV / interval).ceil() * interval;
    if (m <= maxV) m += interval;
    return m;
  }

  Widget Function(double, TitleMeta) _bottomLabels(List labels, int step) {
    return (v, meta) {
      final i = v.round();
      if ((v - i).abs() > 0.001 || i < 0 || i >= labels.length || i % step != 0) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          '${labels[i]}',
          maxLines: 1,
          softWrap: false,
          style: const TextStyle(fontSize: 10),
        ),
      );
    };
  }

  Widget _empty(String msg, double h) => SizedBox(
        height: h,
        child: Center(child: Text(msg, style: const TextStyle(color: Colors.grey))),
      );

  Widget _stat(String title, String val, num growth, IconData icon, Color color) {
    final up = growth >= 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6ECF5)),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(val, maxLines: 1, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 4),
            Row(children: [
              Icon(up ? Icons.trending_up : Icons.trending_down, size: 16, color: up ? kGreen : kRed),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '${pct(growth)}% vs last month',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: up ? kGreen : kRed, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _grid(List<Widget> items, int cols) {
    if (cols <= 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 12),
              child: items[i],
            ),
        ],
      );
    }
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += cols) {
      final chunk = items.skip(i).take(cols).toList();
      rows.add(Padding(
        padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var j = 0; j < cols; j++) ...[
            if (j > 0) const SizedBox(width: 12),
            Expanded(child: j < chunk.length ? chunk[j] : const SizedBox()),
          ],
        ]),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }

  Widget _twoCol(bool wide, List<Widget> children, [List<int>? flexes]) {
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == children.length - 1 ? 0 : 16),
              child: children[i],
            ),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          Expanded(flex: flexes != null && i < flexes.length ? flexes[i] : 1, child: children[i]),
        ],
      ],
    );
  }

  Widget _cell(String t, {double maxW = 180, bool bold = false}) => ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: Text(
          t,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: bold ? FontWeight.w600 : FontWeight.w400),
        ),
      );

  Widget _table(List<String> cols, List<List<Widget>> rows) {
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: Text('No records available', style: TextStyle(color: Colors.grey))),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 40,
        dataRowMinHeight: 44,
        dataRowMaxHeight: 44,
        columnSpacing: 24,
        columns: cols
            .map((e) => DataColumn(label: Text(e, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))))
            .toList(),
        rows: rows.map((r) => DataRow(cells: r.map((c) => DataCell(c)).toList())).toList(),
      ),
    );
  }

  // -------------------------------------------------------------- charts
  Widget _legend(String t, Color c) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.circle, size: 8, color: c),
        const SizedBox(width: 4),
        Text(t, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ]);

  Widget _growth(Map<String, dynamic> g) {
    final labels = asList(g['labels']);
    final total = asList(g['total']);
    final active = asList(g['active']);
    if (total.isEmpty && active.isEmpty) return _empty('No growth data available', 200);

    final count = math.max(labels.length, math.max(total.length, active.length));
    var maxV = 0.0;
    for (final v in [...total, ...active]) {
      maxV = math.max(maxV, asNum(v).toDouble());
    }
    final yInt = _niceInterval(maxV);
    final maxY = _axisMax(maxV, yInt);

    LineChartBarData line(List vals, Color c, {bool fill = false}) => LineChartBarData(
          spots: [
            for (var i = 0; i < vals.length; i++) FlSpot(i.toDouble(), asNum(vals[i]).toDouble()),
          ],
          color: c,
          barWidth: 3,
          isCurved: vals.length > 2,
          dotData: FlDotData(show: vals.length <= 1),
          belowBarData: BarAreaData(show: fill, color: c.withValues(alpha: 0.08)),
        );

    return LayoutBuilder(builder: (context, cons) {
      final w = cons.maxWidth.isFinite ? cons.maxWidth : 320.0;
      final fit = math.max(2, ((w - 56) / 54).floor());
      final step = math.max(1, (count / fit).ceil());
      return SizedBox(
        height: 220,
        child: LineChart(LineChartData(
          minX: 0,
          maxX: math.max(1, count - 1).toDouble(),
          minY: 0,
          maxY: maxY,
          gridData: FlGridData(drawVerticalLine: false, horizontalInterval: yInt),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: yInt,
                getTitlesWidget: (v, m) => Text(compactNum(v), style: const TextStyle(fontSize: 10)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 28,
                getTitlesWidget: _bottomLabels(labels, step),
              ),
            ),
          ),
          lineBarsData: [
            if (total.isNotEmpty) line(total, kBlue, fill: true),
            if (active.isNotEmpty) line(active, kGreen),
          ],
        )),
      );
    });
  }

  Widget _revenue(Map<String, dynamic> r) {
    final labels = asList(r['labels']);
    final vals = asList(r['values']);
    if (vals.isEmpty) return _empty('No coin volume history available', 220);

    final count = math.max(labels.length, vals.length);
    var maxV = 0.0;
    for (final v in vals) {
      maxV = math.max(maxV, asNum(v).toDouble());
    }
    final yInt = _niceInterval(maxV);
    final maxY = _axisMax(maxV, yInt);

    return LayoutBuilder(builder: (context, cons) {
      final w = cons.maxWidth.isFinite ? cons.maxWidth : 320.0;
      final fit = math.max(2, ((w - 60) / 54).floor());
      final step = math.max(1, (count / fit).ceil());
      final barW = math.max(5.0, math.min(18.0, (w - 60) / count * 0.55));
      return SizedBox(
        height: 220,
        child: BarChart(BarChartData(
          alignment: BarChartAlignment.spaceAround,
          minY: 0,
          maxY: maxY,
          gridData: FlGridData(drawVerticalLine: false, horizontalInterval: yInt),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: yInt,
                getTitlesWidget: (v, m) => Text(compactNum(v), style: const TextStyle(fontSize: 10)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: _bottomLabels(labels, step),
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < vals.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: asNum(vals[i]).toDouble(),
                    color: kBlue,
                    width: barW,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(4),
                    ),
                  ),
                ],
              ),
          ],
        )),
      );
    });
  }

  Widget _modes(List modes) {
    final items = modes.map(asMap).toList();
    if (items.isEmpty) return _empty('No game mode statistics yet', 180);

    final totalCount = items.fold<double>(0, (a, m) => a + asNum(m['count']).toDouble());
    double percentOf(Map<String, dynamic> m) {
      if (m['percent'] != null) return asNum(m['percent']).toDouble();
      return totalCount > 0 ? asNum(m['count']).toDouble() / totalCount * 100 : 0;
    }

    final sections = <PieChartSectionData>[
      for (var i = 0; i < items.length; i++)
        if (percentOf(items[i]) > 0)
          PieChartSectionData(
            value: percentOf(items[i]),
            color: modeColors[i % modeColors.length],
            title: '',
            radius: 26,
          ),
    ];

    final pie = SizedBox(
      width: 160,
      height: 160,
      child: PieChart(PieChartData(
        centerSpaceRadius: 44,
        sectionsSpace: 2,
        sections: sections.isEmpty
            ? [PieChartSectionData(value: 100, color: Colors.grey.shade300, title: '', radius: 24)]
            : sections,
      )),
    );

    final legend = Column(children: [
      for (var i = 0; i < items.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            Icon(Icons.circle, size: 10, color: modeColors[i % modeColors.length]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${items[i]['label'] ?? items[i]['name'] ?? 'Mode'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${pct(percentOf(items[i]))}%  (${compactNum(asNum(items[i]['count']))})',
              maxLines: 1,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ]),
        ),
    ]);

    return LayoutBuilder(builder: (context, cons) {
      if (cons.maxWidth < 380) {
        return Column(children: [pie, const SizedBox(height: 12), legend]);
      }
      return Row(children: [pie, const SizedBox(width: 16), Expanded(child: legend)]);
    });
  }

  // ------------------------------------------------------- list sections
  Widget _activities(List a) {
    if (a.isEmpty) {
      return const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('No recent activities logged')));
    }
    return Column(children: [
      for (final raw in a)
        Builder(builder: (_) {
          final e = asMap(raw);
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFE8F0FF),
              child: Icon(Icons.bolt, color: kBlue, size: 18),
            ),
            title: Text(
              asStr(e['title'], 'Activity'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            subtitle: Text(
              asStr(e['sub']),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Text(timeOnly(e['time']), style: const TextStyle(fontSize: 11, color: Colors.grey)),
          );
        }),
    ]);
  }

  Widget _online(Map<String, dynamic> o) {
    final list = asList(o['list']);
    if (list.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: Text('No players currently in active matches')),
      );
    }
    return Column(children: [
      for (final raw in list)
        Builder(builder: (_) {
          final e = asMap(raw);
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(radius: 16, child: Icon(Icons.person, size: 18)),
            title: Text(
              asStr(e['name'], 'Player'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            subtitle: Text(
              asStr(e['where'], 'In Match'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Text(asStr(e['ago']), style: const TextStyle(fontSize: 11, color: Colors.grey)),
          );
        }),
    ]);
  }

  Widget _health(Map<String, dynamic> h) {
    String val(dynamic v, String Function(num) fmt) => v == null ? '—' : fmt(asNum(v));
    Widget r(IconData i, String t, Widget v, {Color color = kGreen}) => ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(i, color: color, size: 20),
          title: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
          trailing: v,
        );
    Widget bold(String s) => Text(s, style: const TextStyle(fontWeight: FontWeight.w700));
    Color okColor(dynamic s) => '$s'.toLowerCase() == 'online' ? kGreen : kRed;

    final backend = asStr(h['backend'], 'Online');
    final database = asStr(h['database'], 'Online');
    final ping = h['dbPingMs'] ?? h['apiResponseMs'];
    return Column(children: [
      r(Icons.dns_outlined, 'Backend Server', statusChip(backend), color: okColor(backend)),
      r(Icons.storage_outlined, 'Database (MongoDB)', statusChip(database), color: okColor(database)),
      r(Icons.speed, 'DB Ping Latency', bold(val(ping, (n) => '${n.toInt()} ms'))),
      r(Icons.timer_outlined, 'Server Uptime', bold(val(h['uptimeSeconds'], formatUptime))),
      r(Icons.memory, 'Memory Usage', bold(val(h['memoryMB'], (n) => '${n.toInt()} MB'))),
      if (h['activeConnections'] != null)
        r(Icons.hub_outlined, 'Active Connections', bold('${asNum(h['activeConnections']).toInt()}')),
    ]);
  }

  Widget _liveBadge(Map<String, dynamic> live) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: kGreen.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.circle, size: 8, color: kGreen),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Live: ${live['matches']} Matches (${live['playersInMatch'] ?? 0} Players)',
              style: const TextStyle(color: kGreen, fontSize: 12, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ]),
      );

  Widget _errorView(String msg) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 48, color: kRed),
            const SizedBox(height: 12),
            Text('Failed to load dashboard data:\n$msg', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _load(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry Connection'),
            ),
          ]),
        ),
      );

  // --------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    final d = _data;
    if (d == null) {
      if (_loading) return const Center(child: CircularProgressIndicator());
      return _errorView(_error ?? 'Invalid response format');
    }

    final st = asMap(d['stats']);
    final live = asMap(d['live']);
    final topGames = asList(d['topGames']).map(asMap).toList();
    final recentUsers = asList(d['recentUsers']).map(asMap).toList();
    final online = asMap(d['onlineUsers']);

    return RefreshIndicator(
      onRefresh: () => _load(fresh: true),
      child: LayoutBuilder(builder: (context, cons) {
        final w = cons.maxWidth - 40; // usable content width
        final wide = w >= 980;
        final kpiCols = w >= 1000 ? 4 : (w >= 560 ? 2 : 1);

        final header = Row(children: [
          Expanded(
            child: Wrap(
              spacing: 12,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Platform Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                if (live['matches'] != null) _liveBadge(live),
                if (_updatedAt != null)
                  Text(
                    'Updated ${_updatedAt!.hour.toString().padLeft(2, '0')}:${_updatedAt!.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _loading ? null : () => _load(fresh: true),
            icon: _refreshing
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh, size: 16),
            label: Text(w < 600 ? 'Refresh' : 'Refresh Data'),
          ),
        ]);

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            header,
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kRed.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: kRed, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Refresh failed, showing last loaded data. $_error',
                      style: const TextStyle(color: kRed, fontSize: 12),
                    ),
                  ),
                  TextButton(onPressed: _loading ? null : () => _load(), child: const Text('Retry')),
                ]),
              ),
            const SizedBox(height: 16),

            // KPI cards
            _grid([
              _stat('Total Users', compactNum(asNum(st['totalUsers'])), asNum(st['usersGrowth']), Icons.person, kBlue),
              _stat('Active Players (30d)', compactNum(asNum(st['activePlayers'])), asNum(st['playersGrowth']),
                  Icons.sports_esports, kGreen),
              _stat('Total Games', compactNum(asNum(st['totalGames'])), asNum(st['gamesGrowth']), Icons.gamepad, kPurple),
              _stat(
                'Coin Volume',
                '🪙 ${compactNum(asNum(st['coinVolume'] ?? st['totalRevenue']))}',
                asNum(st['coinVolumeGrowth'] ?? st['revenueGrowth']),
                Icons.monetization_on,
                kOrange,
              ),
            ], kpiCols),
            const SizedBox(height: 16),

            _twoCol(wide, [
              card(
                'User Growth Trend',
                _growth(asMap(d['growth'])),
                trailing: Wrap(spacing: 10, children: [_legend('Total', kBlue), _legend('Active', kGreen)]),
              ),
              card('Game Mode Breakdown', _modes(asList(d['modes']))),
            ], [3, 2]),
            const SizedBox(height: 16),

            _twoCol(wide, [
              card(
                'Top Games & Rooms',
                _table(['#', 'Room ID', 'Mode', 'Players', 'Status', 'Created At'], [
                  for (var i = 0; i < topGames.length; i++)
                    [
                      Text('${i + 1}'),
                      _cell(asStr(topGames[i]['roomId'])),
                      _cell(asStr(topGames[i]['modeLabel'] ?? topGames[i]['mode'])),
                      Text(asStr(topGames[i]['playersLabel'] ?? topGames[i]['players'])),
                      statusChip(asStr(topGames[i]['status'])),
                      Text(shortDate(topGames[i]['createdAt'], time: true)),
                    ],
                ]),
              ),
              card('Coin Volume Trend', _revenue(asMap(d['revenue']))),
            ], [3, 2]),
            const SizedBox(height: 16),

            _twoCol(wide, [
              card(
                'Recent Users',
                _table(['#', 'Name', 'Email', 'Joined On', 'Status'], [
                  for (var i = 0; i < recentUsers.length; i++)
                    [
                      Text('${i + 1}'),
                      _cell(asStr(recentUsers[i]['name']), bold: true),
                      _cell(asStr(recentUsers[i]['email']), maxW: 220),
                      Text(shortDate(recentUsers[i]['joinedOn'])),
                      statusChip(asStr(recentUsers[i]['status'], 'Active')),
                    ],
                ]),
              ),
              card('Server & Infrastructure Health', _health(asMap(d['health']))),
            ], [3, 2]),
            const SizedBox(height: 16),

            _twoCol(wide, [
              card('Recent Platform Activities', _activities(asList(d['activities']))),
              card('Live Seated Players (${asNum(online['count']).toInt()})', _online(online)),
            ]),
          ]),
        );
      }),
    );
  }
}
