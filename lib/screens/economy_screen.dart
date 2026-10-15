import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../utils/safe.dart';
import '../widgets/date_range_filter.dart';

class EconomyScreen extends StatefulWidget {
  const EconomyScreen({super.key});
  @override
  State<EconomyScreen> createState() => _EconomyScreenState();
}

class _EconomyScreenState extends State<EconomyScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Economy Summary State
  bool _summaryLoading = false;
  String? _summaryError;
  Map<String, dynamic> _summaryData = {};
  List<dynamic> _dailyRows = [];

  // Transactions State
  bool _txLoading = false;
  String? _txError;
  List<dynamic> _transactions = [];
  String _selectedTxType = 'all'; // all, credit, debit
  String _selectedTxSource = 'all'; // all, game_reward, game_entry, bonus, admin, refund, other
  final _txUserCtrl = TextEditingController();
  DateTimeRange? _txRange;
  int _txPage = 1;
  final int _txLimit = 15;
  int _txTotalPages = 1;
  int _txTotalCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchSummary();
    _fetchTransactions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _txUserCtrl.dispose();
    super.dispose();
  }

  void _applyTxFilters() {
    final uid = _txUserCtrl.text.trim();
    if (uid.isNotEmpty && !isMongoId(uid)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User ID must be a 24-character id (copy it from User Details)'),
          backgroundColor: kRed,
        ),
      );
      return;
    }
    setState(() => _txPage = 1);
    _fetchTransactions();
  }

  Widget _txAdvancedFilters() {
    return Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
      SizedBox(
        width: 290,
        child: TextField(
          controller: _txUserCtrl,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _applyTxFilters(),
          decoration: const InputDecoration(
            hintText: 'Filter by User ID...',
            prefixIcon: Icon(Icons.person_search),
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
      ),
      DateRangeFilter(
        value: _txRange,
        onChanged: (v) {
          setState(() => _txRange = v);
          _applyTxFilters();
        },
      ),
      if (_txUserCtrl.text.isNotEmpty || _txRange != null)
        TextButton.icon(
          onPressed: () {
            _txUserCtrl.clear();
            setState(() {
              _txRange = null;
              _txPage = 1;
            });
            _fetchTransactions();
          },
          icon: const Icon(Icons.clear_all, size: 18),
          label: const Text('Clear'),
        ),
    ]);
  }

  int _summaryReq = 0;
  Future<void> _fetchSummary() async {
    final r = ++_summaryReq;
    setState(() {
      _summaryLoading = true;
      _summaryError = null;
    });

    try {
      final summaryRes = await ApiService.get('/admin/economy/summary');
      final reportsRes = await ApiService.get('/admin/reports/daily?days=30');
      if (!mounted || r != _summaryReq) return;

      setState(() {
        _summaryData = asMap(asMap(summaryRes)['data']);
        final rData = asMap(asMap(reportsRes)['data']);
        _dailyRows = asList(rData['rows']);
      });
    } catch (e) {
      if (mounted && r == _summaryReq) setState(() => _summaryError = '$e');
    } finally {
      if (mounted && r == _summaryReq) setState(() => _summaryLoading = false);
    }
  }

  int _txReq = 0;
  Future<void> _fetchTransactions() async {
    final r = ++_txReq;
    setState(() {
      _txLoading = true;
      _txError = null;
    });

    try {
      final query = <String, dynamic>{
        'page': _txPage,
        'limit': _txLimit,
      };
      if (_selectedTxType != 'all') query['type'] = _selectedTxType;
      if (_selectedTxSource != 'all') query['source'] = _selectedTxSource;
      final uid = _txUserCtrl.text.trim();
      if (uid.isNotEmpty && isMongoId(uid)) query['userId'] = uid;
      query.addAll(rangeQuery(_txRange));

      final res = await ApiService.get('/admin/transactions', query: query);
      if (!mounted || r != _txReq) return;
      final data = (res is Map && res['data'] is Map) ? res['data'] as Map : {};
      final list = (data['transactions'] is List) ? data['transactions'] as List : [];
      final pagination = (data['pagination'] is Map) ? data['pagination'] as Map : {};

      setState(() {
        _transactions = list;
        _txPage = (pagination['page'] is num) ? (pagination['page'] as num).toInt() : _txPage;
        _txTotalPages = (pagination['totalPages'] is num) ? math.max(1, (pagination['totalPages'] as num).toInt()) : 1;
        _txTotalCount = (pagination['total'] is num) ? (pagination['total'] as num).toInt() : list.length;
      });
    } catch (e) {
      if (mounted && r == _txReq) setState(() => _txError = '$e');
    } finally {
      if (mounted && r == _txReq) setState(() => _txLoading = false);
    }
  }

  Widget _buildSummaryTab() {
    if (_summaryLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_summaryError != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Error loading economy data: $_summaryError', style: const TextStyle(color: kRed)),
          const SizedBox(height: 8),
          FilledButton(onPressed: _fetchSummary, child: const Text('Retry')),
        ]),
      );
    }

    final coinsCirc = _summaryData['coinsInCirculation'] ?? 0;
    final wallets = _summaryData['wallets'] ?? 0;
    final last30 = (_summaryData['last30Days'] is Map) ? _summaryData['last30Days'] as Map : {};
    final flows = (last30['flows'] is List) ? last30['flows'] as List : [];
    final platformRev = (_summaryData['platformRevenue'] is Map) ? _summaryData['platformRevenue'] as Map : {};
    final coinVol = (_summaryData['coinVolume'] is Map) ? _summaryData['coinVolume'] as Map : {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Top KPI Cards
        LayoutBuilder(
          builder: (context, constraints) {
            final cards = [
              _kpiCard('Coins in Circulation', formatCurrency(coinsCirc), Icons.account_balance_wallet, kOrange),
              _kpiCard('Active Wallets', '$wallets', Icons.people_outline, kBlue),
              _kpiCard('Platform Revenue (30d)', formatCurrency(platformRev['last30Days'] ?? 0), Icons.savings, kGreen),
              _kpiCard('Coin Volume (30d)', formatCurrency(coinVol['last30Days'] ?? 0), Icons.bar_chart, kPurple),
            ];

            if (constraints.maxWidth < 700) {
              return Column(
                children: cards.expand((c) => [c, const SizedBox(height: 12)]).toList()..removeLast(),
              );
            }
            if (constraints.maxWidth < 1100) {
              return Column(
                children: [
                  Row(children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 14),
                    Expanded(child: cards[1]),
                  ]),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: cards[2]),
                    const SizedBox(width: 14),
                    Expanded(child: cards[3]),
                  ]),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 14),
                Expanded(child: cards[1]),
                const SizedBox(width: 14),
                Expanded(child: cards[2]),
                const SizedBox(width: 14),
                Expanded(child: cards[3]),
              ],
            );
          },
        ),
        const SizedBox(height: 20),

        // 30 Days Source-wise flows
        card(
          '30-Day Wallet Flow Breakdown',
          flows.isEmpty
              ? const Padding(padding: EdgeInsets.all(20), child: Text('No flows in last 30 days'))
              : Column(children: [
                  for (final f in flows)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        f['type'] == 'credit' ? Icons.arrow_downward : Icons.arrow_upward,
                        color: f['type'] == 'credit' ? kGreen : kRed,
                      ),
                      title: Text(
                        'Source: ${f['source'] ?? 'unknown'} (${f['type']?.toUpperCase()})',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text('${f['count'] ?? 0} transactions'),
                      trailing: Text(
                        '${f['type'] == 'credit' ? '+' : '-'}${formatCurrency(f['amount'] ?? 0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: f['type'] == 'credit' ? kGreen : kRed,
                        ),
                      ),
                    ),
                ]),
        ),
        const SizedBox(height: 20),

        // 30-Day Daily Series Table
        card(
          'Daily Performance Report (Last 30 Days)',
          _dailyRows.isEmpty
              ? const Padding(padding: EdgeInsets.all(20), child: Text('No daily data available'))
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 40,
                      columns: const [
                        DataColumn(label: Text('DATE')),
                        DataColumn(label: Text('NEW USERS')),
                        DataColumn(label: Text('ACTIVE PLAYERS')),
                        DataColumn(label: Text('MATCHES')),
                        DataColumn(label: Text('COIN VOLUME')),
                        DataColumn(label: Text('PLATFORM REVENUE')),
                      ],
                      rows: [
                        for (final r in _dailyRows.reversed)
                          DataRow(cells: [
                            DataCell(Text('${r['label'] ?? r['date'] ?? ''}')),
                            DataCell(Text('${r['newUsers'] ?? 0}')),
                            DataCell(Text('${r['activePlayers'] ?? 0}')),
                            DataCell(Text('${r['games'] ?? 0}')),
                            DataCell(Text(formatCurrency(r['coinVolume'] ?? 0))),
                            DataCell(Text(formatCurrency(r['platformRevenue'] ?? 0))),
                          ]),
                      ],
                    ),
                  ),
                ]),
        ),
      ]),
    );
  }

  Widget _kpiCard(String title, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6ECF5)),
      ),
      child: Row(children: [
        CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(val, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildTransactionsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Filter Card
        card(
          'Transactions Ledger ($_txTotalCount Total)',
          Wrap(
            spacing: 14,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButton<String>(
                value: _selectedTxType,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Types (Credit & Debit)')),
                  DropdownMenuItem(value: 'credit', child: Text('Credit (+)')),
                  DropdownMenuItem(value: 'debit', child: Text('Debit (-)')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _selectedTxType = v;
                      _txPage = 1;
                    });
                    _fetchTransactions();
                  }
                },
              ),
              DropdownButton<String>(
                value: _selectedTxSource,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Sources')),
                  DropdownMenuItem(value: 'game_reward', child: Text('Game Reward')),
                  DropdownMenuItem(value: 'game_entry', child: Text('Game Entry Fee')),
                  DropdownMenuItem(value: 'bonus', child: Text('Bonus / Signup')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin Adjustment')),
                  DropdownMenuItem(value: 'refund', child: Text('Refund')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _selectedTxSource = v;
                      _txPage = 1;
                    });
                    _fetchTransactions();
                  }
                },
              ),
              FilledButton.icon(
                onPressed: () {
                  setState(() => _txPage = 1);
                  _fetchTransactions();
                },
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh Ledger'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _txAdvancedFilters(),
        const SizedBox(height: 16),

        // Transactions Table Card
        card(
          'Transaction Records',
          _txLoading
              ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
              : _txError != null
                  ? Center(
                      child: Column(children: [
                        Text('Error loading ledger: $_txError', style: const TextStyle(color: kRed)),
                        const SizedBox(height: 8),
                        TextButton(onPressed: _fetchTransactions, child: const Text('Retry')),
                      ]),
                    )
                  : _transactions.isEmpty
                      ? const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No transactions recorded')))
                      : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('#')),
                                DataColumn(label: Text('USER')),
                                DataColumn(label: Text('TYPE')),
                                DataColumn(label: Text('AMOUNT')),
                                DataColumn(label: Text('SOURCE')),
                                DataColumn(label: Text('BALANCE BEFORE')),
                                DataColumn(label: Text('BALANCE AFTER')),
                                DataColumn(label: Text('DESCRIPTION')),
                                DataColumn(label: Text('DATE')),
                              ],
                              rows: [
                                for (var i = 0; i < _transactions.length; i++)
                                  DataRow(cells: [
                                    DataCell(Text('${(_txPage - 1) * _txLimit + i + 1}')),
                                    DataCell(Text(
                                      _transactions[i]['user']?['name'] ?? _transactions[i]['user']?['email'] ?? 'Unknown',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    )),
                                    DataCell(statusChip('${_transactions[i]['type']}')),
                                    DataCell(Text(
                                      '${_transactions[i]['type'] == 'credit' ? '+' : '-'}${formatCurrency(_transactions[i]['amount'] ?? 0)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _transactions[i]['type'] == 'credit' ? kGreen : kRed,
                                      ),
                                    )),
                                    DataCell(Text('${_transactions[i]['source'] ?? ''}')),
                                    DataCell(Text(formatCurrency(_transactions[i]['balanceBefore'] ?? 0))),
                                    DataCell(Text(formatCurrency(_transactions[i]['balanceAfter'] ?? 0))),
                                    DataCell(Text('${_transactions[i]['description'] ?? ''}')),
                                    DataCell(Text(shortDate(_transactions[i]['createdAt'], time: true))),
                                  ]),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Pagination Controls
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              Text('Page $_txPage of $_txTotalPages ($_txTotalCount transactions)', style: const TextStyle(color: Colors.grey)),
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                OutlinedButton(
                                  onPressed: _txPage > 1 ? () { setState(() => _txPage--); _fetchTransactions(); } : null,
                                  child: const Text('Previous'),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: _txPage < _txTotalPages ? () { setState(() => _txPage++); _fetchTransactions(); } : null,
                                  child: const Text('Next'),
                                ),
                              ]),
                            ],
                          ),
                        ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: kBlue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: kBlue,
            tabs: const [
              Tab(text: 'Economy Overview & Daily Reports'),
              Tab(text: 'Transactions Ledger'),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSummaryTab(),
          _buildTransactionsTab(),
        ],
      ),
    );
  }
}
