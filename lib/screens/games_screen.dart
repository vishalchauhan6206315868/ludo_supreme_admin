import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../utils/safe.dart';

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});
  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  final _roomCodeController = TextEditingController();
  final _debounce = Debouncer();

  @override
  void dispose() {
    _debounce.dispose();
    _roomCodeController.dispose();
    super.dispose();
  }

  String _selectedStatus = 'all'; // all, in_progress, completed, abandoned
  String _selectedMode = 'all'; // all, twoPlayer, fourPlayer
  int _page = 1;
  final int _limit = 15;
  int _totalPages = 1;
  int _totalGames = 0;

  bool _loading = false;
  String? _error;
  List<dynamic> _games = [];

  @override
  void initState() {
    super.initState();
    _fetchGames();
  }

  int _gamesReq = 0;
  Future<void> _fetchGames() async {
    final r = ++_gamesReq;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final query = <String, dynamic>{
        'page': _page,
        'limit': _limit,
      };
      final room = _roomCodeController.text.trim();
      if (room.isNotEmpty) query['roomCode'] = room;
      if (_selectedStatus != 'all') query['status'] = _selectedStatus;
      if (_selectedMode != 'all') query['mode'] = _selectedMode;

      final res = await ApiService.get('/admin/games', query: query);
      if (!mounted || r != _gamesReq) return;
      final data = (res is Map && res['data'] is Map) ? res['data'] as Map : {};
      final list = (data['games'] is List) ? (data['games'] as List) : [];
      final pagination = (data['pagination'] is Map) ? (data['pagination'] as Map) : {};

      setState(() {
        _games = list;
        _page = (pagination['page'] is num) ? (pagination['page'] as num).toInt() : _page;
        _totalPages = (pagination['totalPages'] is num) ? math.max(1, (pagination['totalPages'] as num).toInt()) : 1;
        _totalGames = (pagination['total'] is num) ? (pagination['total'] as num).toInt() : list.length;
      });
    } catch (e) {
      if (mounted && r == _gamesReq) setState(() => _error = '$e');
    } finally {
      if (mounted && r == _gamesReq) setState(() => _loading = false);
    }
  }

  void _inspectGame(String id) async {
    if (id.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final res = await ApiService.get('/admin/games/$id');
      if (!mounted) return;
      Navigator.pop(context); // close loading

      final data = (res is Map && res['data'] is Map) ? res['data'] as Map : {};
      final game = (data['game'] is Map) ? data['game'] as Map : {};
      final players = (game['players'] is List) ? (game['players'] as List) : [];
      final moves = (game['moves'] is List) ? (game['moves'] as List) : [];

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(children: [
            const Icon(Icons.sports_esports, color: kPurple),
            const SizedBox(width: 10),
            Text('Room #${game['roomCode'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            statusChip('${game['status'] ?? ''}'),
          ]),
          content: SizedBox(
            width: math.min(760, MediaQuery.sizeOf(context).width * 0.95),
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Divider(),
                // Meta Overview
                Wrap(alignment: WrapAlignment.spaceAround, spacing: 16, runSpacing: 12, children: [
                  _meta('Mode', game['mode'] == 'twoPlayer' ? '2 Player' : '4 Player'),
                  _meta('Entry Fee', formatCurrency(game['entryFee'] ?? 0)),
                  _meta('Prize Pool', formatCurrency(game['prizePool'] ?? 0)),
                  _meta('Winner', '${game['winner'] ?? 'None / In Progress'}'),
                ]),
                const Divider(height: 28),

                // Seated Players
                const Text('Players & Token States', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 36,
                    dataRowMinHeight: 38,
                    dataRowMaxHeight: 38,
                    columns: const [
                      DataColumn(label: Text('Player')),
                      DataColumn(label: Text('Color')),
                      DataColumn(label: Text('Score')),
                      DataColumn(label: Text('Outcome')),
                      DataColumn(label: Text('Prize Earned')),
                      DataColumn(label: Text('Surrendered')),
                    ],
                    rows: players.map((p) => DataRow(cells: [
                      DataCell(Text('${p['name'] ?? 'Player'}', style: const TextStyle(fontWeight: FontWeight.w600))),
                      DataCell(Text('${p['color'] ?? ''}')),
                      DataCell(Text('${p['score'] ?? 0}')),
                      DataCell(statusChip('${p['outcome'] ?? 'active'}')),
                      DataCell(Text(formatCurrency(p['prizeEarned'] ?? 0))),
                      DataCell(Text(p['hasSurrendered'] == true ? 'Yes' : 'No')),
                    ])).toList(),
                  ),
                ),
                const SizedBox(height: 20),

                // Moves log
                Text('Last ${moves.length} Moves History', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                if (moves.isEmpty)
                  const Padding(padding: EdgeInsets.all(12), child: Text('No moves recorded yet', style: TextStyle(color: Colors.grey)))
                else
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      itemCount: moves.length,
                      itemBuilder: (_, i) {
                        final m = moves[i];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                          ),
                          child: Wrap(runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                            Text('#${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                            const SizedBox(width: 12),
                            Text('${m['player'] ?? m['user'] ?? 'Turn'}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                            const SizedBox(width: 12),
                            Text('Dice: ${m['dice'] ?? m['diceValue'] ?? '-'}', style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 12),
                            Text('Action: ${m['action'] ?? m['type'] ?? 'move'}', style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                            Text('${m['at'] ?? m['timestamp'] ?? ''}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ]),
                        );
                      },
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
        SnackBar(content: Text('Failed to load game: $e'), backgroundColor: kRed),
      );
    }
  }

  Widget _meta(String label, String value) {
    return Column(children: [
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Filter Card
        card(
          'Match & Game Operations ($_totalGames Total)',
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 800;
              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _roomCodeController,
                      decoration: const InputDecoration(
                        hintText: 'Search by Room Code (e.g. 10423)...',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => _debounce.run(() {
                        if (!mounted) return;
                        setState(() => _page = 1);
                        _fetchGames();
                      }),
                      onSubmitted: (_) {
                        setState(() => _page = 1);
                        _fetchGames();
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
                            DropdownMenuItem(value: 'in_progress', child: Text('In Progress')),
                            DropdownMenuItem(value: 'completed', child: Text('Completed')),
                            DropdownMenuItem(value: 'abandoned', child: Text('Abandoned')),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() {
                                _selectedStatus = v;
                                _page = 1;
                              });
                              _fetchGames();
                            }
                          },
                        ),
                        DropdownButton<String>(
                          value: _selectedMode,
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('All Modes')),
                            DropdownMenuItem(value: 'twoPlayer', child: Text('2 Player')),
                            DropdownMenuItem(value: 'fourPlayer', child: Text('4 Player')),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() {
                                _selectedMode = v;
                                _page = 1;
                              });
                              _fetchGames();
                            }
                          },
                        ),
                        FilledButton.icon(
                          onPressed: () {
                            setState(() => _page = 1);
                            _fetchGames();
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
                    controller: _roomCodeController,
                    decoration: const InputDecoration(
                      hintText: 'Search by Room Code (e.g. 10423)...',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => _debounce.run(() {
                      if (!mounted) return;
                      setState(() => _page = 1);
                      _fetchGames();
                    }),
                    onSubmitted: (_) {
                      setState(() => _page = 1);
                      _fetchGames();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _selectedStatus,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                    DropdownMenuItem(value: 'in_progress', child: Text('In Progress')),
                    DropdownMenuItem(value: 'completed', child: Text('Completed')),
                    DropdownMenuItem(value: 'abandoned', child: Text('Abandoned')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _selectedStatus = v;
                        _page = 1;
                      });
                      _fetchGames();
                    }
                  },
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _selectedMode,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Modes')),
                    DropdownMenuItem(value: 'twoPlayer', child: Text('2 Player')),
                    DropdownMenuItem(value: 'fourPlayer', child: Text('4 Player')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _selectedMode = v;
                        _page = 1;
                      });
                      _fetchGames();
                    }
                  },
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () {
                    setState(() => _page = 1);
                    _fetchGames();
                  },
                  icon: const Icon(Icons.filter_list, size: 16),
                  label: const Text('Filter'),
                ),
              ]);
            },
          ),
        ),
        const SizedBox(height: 16),

        // Games Table Card
        card(
          'Games List',
          _loading
              ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
              : _error != null
                  ? Center(
                      child: Column(children: [
                        Text('Error loading games: $_error', style: const TextStyle(color: kRed)),
                        const SizedBox(height: 8),
                        TextButton(onPressed: _fetchGames, child: const Text('Retry')),
                      ]),
                    )
                  : _games.isEmpty
                      ? const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No games found matching criteria')))
                      : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('#')),
                                DataColumn(label: Text('ROOM CODE')),
                                DataColumn(label: Text('MODE')),
                                DataColumn(label: Text('STATUS')),
                                DataColumn(label: Text('ENTRY FEE')),
                                DataColumn(label: Text('PRIZE POOL')),
                                DataColumn(label: Text('PLAYERS')),
                                DataColumn(label: Text('CREATED AT')),
                                DataColumn(label: Text('ACTIONS')),
                              ],
                              rows: [
                                for (var i = 0; i < _games.length; i++)
                                  DataRow(cells: [
                                    DataCell(Text('${(_page - 1) * _limit + i + 1}')),
                                    DataCell(Text(_games[i]['roomCode']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                                    DataCell(Text(_games[i]['mode'] == 'twoPlayer' ? '2 Player' : '4 Player')),
                                    DataCell(statusChip('${_games[i]['status'] ?? ''}')),
                                    DataCell(Text(formatCurrency(_games[i]['entryFee'] ?? 0))),
                                    DataCell(Text(formatCurrency(_games[i]['prizePool'] ?? 0))),
                                    DataCell(Text(((_games[i]['players'] is List) ? (_games[i]['players'] as List).length : 0).toString())),
                                    DataCell(Text(_games[i]['createdAt'] != null ? _games[i]['createdAt'].toString().substring(0, math.min(16, _games[i]['createdAt'].toString().length)) : '')),
                                    DataCell(
                                      IconButton(
                                        icon: const Icon(Icons.remove_red_eye_outlined, size: 20, color: kBlue),
                                        tooltip: 'Inspect Board & Moves',
                                        onPressed: () => _inspectGame('${_games[i]['id'] ?? _games[i]['_id'] ?? ''}'),
                                      ),
                                    ),
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
                              Text('Page $_page of $_totalPages ($_totalGames matches)', style: const TextStyle(color: Colors.grey)),
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                OutlinedButton(
                                  onPressed: _page > 1 ? () { setState(() => _page--); _fetchGames(); } : null,
                                  child: const Text('Previous'),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: _page < _totalPages ? () { setState(() => _page++); _fetchGames(); } : null,
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
