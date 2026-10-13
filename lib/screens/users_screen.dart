import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../utils/safe.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _searchController = TextEditingController();
  final _debounce = Debouncer();

  @override
  void dispose() {
    _debounce.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _selectedStatus = 'all'; // all, active, blocked
  String _selectedSort = 'newest'; // newest, oldest, name
  int _page = 1;
  final int _limit = 15;
  int _totalPages = 1;
  int _totalUsers = 0;

  bool _loading = false;
  String? _error;
  List<dynamic> _users = [];

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  int _usersReq = 0;
  Future<void> _fetchUsers() async {
    final r = ++_usersReq;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final query = <String, dynamic>{
        'page': _page,
        'limit': _limit,
        'sort': _selectedSort,
      };
      final search = _searchController.text.trim();
      if (search.isNotEmpty) query['search'] = search;
      if (_selectedStatus != 'all') query['status'] = _selectedStatus;

      final res = await ApiService.get('/admin/users', query: query);
      if (!mounted || r != _usersReq) return;
      final data = (res is Map && res['data'] is Map) ? res['data'] as Map : {};
      final list = (data['users'] is List) ? (data['users'] as List) : [];
      final pagination = (data['pagination'] is Map) ? (data['pagination'] as Map) : {};

      setState(() {
        _users = list;
        _page = (pagination['page'] is num) ? (pagination['page'] as num).toInt() : _page;
        _totalPages = (pagination['totalPages'] is num) ? math.max(1, (pagination['totalPages'] as num).toInt()) : 1;
        _totalUsers = (pagination['total'] is num) ? (pagination['total'] as num).toInt() : list.length;
      });
    } catch (e) {
      if (mounted && r == _usersReq) setState(() => _error = '$e');
    } finally {
      if (mounted && r == _usersReq) setState(() => _loading = false);
    }
  }

  void _showUserDetails(String id) async {
    if (id.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final res = await ApiService.get('/admin/users/$id');
      if (!mounted) return;
      Navigator.pop(context); // close loading

      final data = (res is Map && res['data'] is Map) ? res['data'] as Map : {};
      final user = (data['user'] is Map) ? data['user'] as Map : {};
      final txs = (data['recentTransactions'] is List) ? (data['recentTransactions'] as List) : [];
      final games = (data['recentGames'] is List) ? (data['recentGames'] as List) : [];

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(children: [
            CircleAvatar(child: Text(initialOf(user['name'], 'U'))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${user['name'] ?? 'User'}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('${user['email'] ?? ''}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ]),
            ),
            statusChip('${user['status'] ?? 'Active'}'),
          ]),
          content: SizedBox(
            width: math.min(720, MediaQuery.sizeOf(context).width * 0.95),
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Divider(),
                // User Stats
                Wrap(alignment: WrapAlignment.spaceAround, spacing: 16, runSpacing: 12, children: [
                  _infoTile('Coins Balance', formatCurrency(user['coins'] ?? 0), Icons.monetization_on, kOrange),
                  _infoTile('Level', '${user['level'] ?? 1}', Icons.star, kPurple),
                  _infoTile('Total Games', '${user['statistics']?['totalGames'] ?? 0}', Icons.gamepad, kBlue),
                  _infoTile('Wins', '${user['statistics']?['wins'] ?? 0}', Icons.emoji_events, kGreen),
                ]),
                const Divider(height: 30),

                // Recent Transactions
                const Text('Recent Wallet Transactions (Last 10)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                if (txs.isEmpty)
                  const Padding(padding: EdgeInsets.all(12), child: Text('No transactions found', style: TextStyle(color: Colors.grey)))
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 36,
                      dataRowMinHeight: 36,
                      dataRowMaxHeight: 36,
                      columns: const [
                        DataColumn(label: Text('Type')),
                        DataColumn(label: Text('Amount')),
                        DataColumn(label: Text('Source')),
                        DataColumn(label: Text('Balance After')),
                        DataColumn(label: Text('Description')),
                      ],
                      rows: txs.map((t) => DataRow(cells: [
                        DataCell(statusChip('${t['type']}')),
                        DataCell(Text('${t['type'] == 'credit' ? '+' : '-'}${t['amount']}')),
                        DataCell(Text('${t['source'] ?? ''}')),
                        DataCell(Text('${t['balanceAfter'] ?? 0}')),
                        DataCell(Text('${t['description'] ?? ''}')),
                      ])).toList(),
                    ),
                  ),

                const SizedBox(height: 20),

                // Recent Games
                const Text('Recent Games (Last 10)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                if (games.isEmpty)
                  const Padding(padding: EdgeInsets.all(12), child: Text('No game history found', style: TextStyle(color: Colors.grey)))
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 36,
                      dataRowMinHeight: 36,
                      dataRowMaxHeight: 36,
                      columns: const [
                        DataColumn(label: Text('Room')),
                        DataColumn(label: Text('Mode')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Prize Won')),
                        DataColumn(label: Text('Outcome')),
                      ],
                      rows: games.map((g) => DataRow(cells: [
                        DataCell(Text('${g['roomCode'] ?? ''}')),
                        DataCell(Text('${g['mode'] ?? ''}')),
                        DataCell(statusChip('${g['status'] ?? ''}')),
                        DataCell(Text(formatCurrency(g['prizeEarned'] ?? 0))),
                        DataCell(Text('${g['outcome'] ?? '-'}')),
                      ])).toList(),
                    ),
                  ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close loading
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to load user: $e'), backgroundColor: kRed),
      );
    }
  }

  Widget _infoTile(String label, String value, IconData icon, Color col) {
    return Column(children: [
      Icon(icon, color: col, size: 24),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
    ]);
  }

  void _showChangeStatusDialog(Map user) {
    final bool currentActive = user['isActive'] != false;
    final reasonController = TextEditingController();
    final bool targetActive = !currentActive;
    final messenger = ScaffoldMessenger.of(context);
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          title: Text(targetActive ? 'Unblock User' : 'Block User'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SizedBox(
              width: math.min(440, MediaQuery.sizeOf(context).width * 0.9),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Are you sure you want to ${targetActive ? 'unblock' : 'block'} ${user['name']}?'),
                const SizedBox(height: 12),
                if (!targetActive) ...[
                  const Text('Reason for blocking (Required, min 3 characters):', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: reasonController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Fair play violation / toxic behavior',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ]),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: targetActive ? kGreen : kRed),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final reason = reasonController.text.trim();
                      if (!targetActive && reason.length < 3) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Reason must be at least 3 characters'), backgroundColor: kRed),
                        );
                        return;
                      }
                      setDState(() => isSubmitting = true);
                      try {
                        await ApiService.patch('/admin/users/${user['id'] ?? user['_id']}/status', {
                          'isActive': targetActive,
                          'reason': reason,
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('User ${targetActive ? 'unblocked' : 'blocked'} successfully'), backgroundColor: kGreen),
                          );
                          _fetchUsers();
                        }
                      } catch (e) {
                        setDState(() => isSubmitting = false);
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('Failed to update status: $e'), backgroundColor: kRed),
                          );
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(targetActive ? 'Confirm Unblock' : 'Confirm Block'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAdjustCoinsDialog(Map user) {
    String type = 'credit';
    final amountController = TextEditingController();
    final idempotencyKey = 'adj_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(999999)}';
    final reasonController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          title: Row(children: [
            const Icon(Icons.monetization_on, color: kOrange),
            const SizedBox(width: 8),
            Expanded(child: Text('Adjust Coins: ${user['name']}', overflow: TextOverflow.ellipsis)),
          ]),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SizedBox(
              width: math.min(440, MediaQuery.sizeOf(context).width * 0.9),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Current Balance: ${formatCurrency(user['coins'] ?? 0)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'credit', label: Text('Credit (+)'), icon: Icon(Icons.add_circle, color: kGreen)),
                      ButtonSegment(value: 'debit', label: Text('Debit (-)'), icon: Icon(Icons.remove_circle, color: kRed)),
                    ],
                    selected: {type},
                    onSelectionChanged: (s) => setDState(() => type = s.first),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount (Coins)',
                    hintText: '1 - 100000',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.numbers),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    hintText: 'Reason for adjustment (3-200 chars)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.edit_note),
                  ),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final amt = int.tryParse(amountController.text.trim()) ?? 0;
                      final rsn = reasonController.text.trim();
                      if (amt <= 0 || amt > 100000) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Amount must be between 1 and 100,000'), backgroundColor: kRed),
                        );
                        return;
                      }
                      if (rsn.length < 3) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Reason must be at least 3 characters'), backgroundColor: kRed),
                        );
                        return;
                      }

                      setDState(() => isSubmitting = true);

                      try {
                        final res = await ApiService.post('/admin/users/${user['id'] ?? user['_id']}/coins', {
                          'type': type,
                          'amount': amt,
                          'reason': rsn,
                          'idempotencyKey': idempotencyKey,
                        });
                        final newBal = asMap(asMap(res)['data'])['balance'] ?? '';
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('Coins adjusted successfully! New balance: $newBal'), backgroundColor: kGreen),
                          );
                          _fetchUsers();
                        }
                      } catch (e) {
                        setDState(() => isSubmitting = false);
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('Failed to adjust coins: $e'), backgroundColor: kRed),
                          );
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Submit Adjustment'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Controls Card
        card(
          'User Management ($_totalUsers Total)',
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 800;
              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search by Name, Email, or Username...',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => _debounce.run(() {
                        if (!mounted) return;
                        setState(() => _page = 1);
                        _fetchUsers();
                      }),
                      onSubmitted: (_) {
                        setState(() => _page = 1);
                        _fetchUsers();
                      },
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        DropdownButton<String>(
                          value: _selectedStatus,
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                            DropdownMenuItem(value: 'active', child: Text('Active Only')),
                            DropdownMenuItem(value: 'blocked', child: Text('Blocked Only')),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() {
                                _selectedStatus = v;
                                _page = 1;
                              });
                              _fetchUsers();
                            }
                          },
                        ),
                        DropdownButton<String>(
                          value: _selectedSort,
                          items: const [
                            DropdownMenuItem(value: 'newest', child: Text('Sort: Newest')),
                            DropdownMenuItem(value: 'oldest', child: Text('Sort: Oldest')),
                            DropdownMenuItem(value: 'name', child: Text('Sort: Name')),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() {
                      _selectedSort = v;
                      _page = 1;
                    });
                              _fetchUsers();
                            }
                          },
                        ),
                        FilledButton.icon(
                          onPressed: () {
                            setState(() => _page = 1);
                            _fetchUsers();
                          },
                          icon: const Icon(Icons.filter_list, size: 16),
                          label: const Text('Filter'),
                        ),
                      ],
                    ),
                  ],
                );
              }
              return Row(children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search by Name, Email, or Username...',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => _debounce.run(() {
                      if (!mounted) return;
                      setState(() => _page = 1);
                      _fetchUsers();
                    }),
                    onSubmitted: (_) {
                      setState(() => _page = 1);
                      _fetchUsers();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _selectedStatus,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                    DropdownMenuItem(value: 'active', child: Text('Active Only')),
                    DropdownMenuItem(value: 'blocked', child: Text('Blocked Only')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _selectedStatus = v;
                        _page = 1;
                      });
                      _fetchUsers();
                    }
                  },
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _selectedSort,
                  items: const [
                    DropdownMenuItem(value: 'newest', child: Text('Sort: Newest')),
                    DropdownMenuItem(value: 'oldest', child: Text('Sort: Oldest')),
                    DropdownMenuItem(value: 'name', child: Text('Sort: Name')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                      _selectedSort = v;
                      _page = 1;
                    });
                      _fetchUsers();
                    }
                  },
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () {
                    setState(() => _page = 1);
                    _fetchUsers();
                  },
                  icon: const Icon(Icons.filter_list, size: 16),
                  label: const Text('Filter'),
                ),
              ]);
            },
          ),
        ),
        const SizedBox(height: 16),

        // Table Card
        card(
          'Registered Users',
          _loading
              ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
              : _error != null
                  ? Center(
                      child: Column(children: [
                        Text('Error loading users: $_error', style: const TextStyle(color: kRed)),
                        const SizedBox(height: 8),
                        TextButton(onPressed: _fetchUsers, child: const Text('Retry')),
                      ]),
                    )
                  : _users.isEmpty
                      ? const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No users matching criteria')))
                      : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('#')),
                                DataColumn(label: Text('NAME')),
                                DataColumn(label: Text('EMAIL')),
                                DataColumn(label: Text('LEVEL')),
                                DataColumn(label: Text('COINS')),
                                DataColumn(label: Text('STATUS')),
                                DataColumn(label: Text('ACTIONS')),
                              ],
                              rows: [
                                for (var i = 0; i < _users.length; i++)
                                  DataRow(cells: [
                                    DataCell(Text('${(_page - 1) * _limit + i + 1}')),
                                    DataCell(Text('${_users[i]['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600))),
                                    DataCell(Text('${_users[i]['email'] ?? ''}')),
                                    DataCell(Text('Lvl ${_users[i]['level'] ?? 1}')),
                                    DataCell(Text(formatCurrency(_users[i]['coins'] ?? 0))),
                                    DataCell(statusChip('${_users[i]['status'] ?? 'Active'}')),
                                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                                      IconButton(
                                        icon: const Icon(Icons.visibility_outlined, size: 20, color: kBlue),
                                        tooltip: 'View Details',
                                        onPressed: () => _showUserDetails('${_users[i]['id'] ?? _users[i]['_id'] ?? ''}'),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          _users[i]['isActive'] == false ? Icons.lock_open : Icons.lock_outline,
                                          size: 20,
                                          color: _users[i]['isActive'] == false ? kGreen : kRed,
                                        ),
                                        tooltip: _users[i]['isActive'] == false ? 'Unblock User' : 'Block User',
                                        onPressed: () => _showChangeStatusDialog(_users[i]),
                                      ),
                                      if (ApiService.isSuperAdmin)
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline, size: 20, color: kOrange),
                                          tooltip: 'Adjust Coins (Super Admin)',
                                          onPressed: () => _showAdjustCoinsDialog(_users[i]),
                                        ),
                                    ])),
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
                              Text('Page $_page of $_totalPages ($_totalUsers users)', style: const TextStyle(color: Colors.grey)),
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                OutlinedButton(
                                  onPressed: _page > 1 ? () { setState(() => _page--); _fetchUsers(); } : null,
                                  child: const Text('Previous'),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: _page < _totalPages ? () { setState(() => _page++); _fetchUsers(); } : null,
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
}
