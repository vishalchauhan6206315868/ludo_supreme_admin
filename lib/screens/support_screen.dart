import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../utils/safe.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});
  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _searchController = TextEditingController();
  final _debounce = Debouncer();

  @override
  void dispose() {
    _debounce.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _selectedStatus = 'all'; // all, open, in_progress, resolved, closed
  String _selectedPriority = 'all'; // all, low, normal, high
  String _selectedCategory = 'all'; // all, payment, game, account, bug, other
  int _page = 1;
  final int _limit = 15;
  int _totalPages = 1;
  int _totalTickets = 0;

  bool _loading = false;
  String? _error;
  List<dynamic> _tickets = [];

  @override
  void initState() {
    super.initState();
    _fetchTickets();
  }

  int _ticketsReq = 0;
  Future<void> _fetchTickets() async {
    final r = ++_ticketsReq;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final query = <String, dynamic>{
        'page': _page,
        'limit': _limit,
      };
      final no = _searchController.text.trim();
      if (no.isNotEmpty) query['ticketNo'] = no;
      if (_selectedStatus != 'all') query['status'] = _selectedStatus;
      if (_selectedPriority != 'all') query['priority'] = _selectedPriority;
      if (_selectedCategory != 'all') query['category'] = _selectedCategory;

      final res = await ApiService.get('/admin/support/tickets', query: query);
      if (!mounted || r != _ticketsReq) return;
      final data = (res is Map && res['data'] is Map) ? res['data'] as Map : {};
      final list = (data['tickets'] is List) ? (data['tickets'] as List) : [];
      final pagination = (data['pagination'] is Map) ? (data['pagination'] as Map) : {};

      setState(() {
        _tickets = list;
        _page = (pagination['page'] is num) ? (pagination['page'] as num).toInt() : _page;
        _totalPages = (pagination['totalPages'] is num) ? math.max(1, (pagination['totalPages'] as num).toInt()) : 1;
        _totalTickets = (pagination['total'] is num) ? (pagination['total'] as num).toInt() : list.length;
      });
    } catch (e) {
      if (mounted && r == _ticketsReq) setState(() => _error = '$e');
    } finally {
      if (mounted && r == _ticketsReq) setState(() => _loading = false);
    }
  }

  void _openTicketChat(String id) async {
    if (id.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final res = await ApiService.get('/admin/support/tickets/$id');
      if (!mounted) return;
      Navigator.pop(context); // close loading

      final data = (res is Map && res['data'] is Map) ? res['data'] as Map : {};
      final ticket = (data['ticket'] is Map) ? data['ticket'] as Map : {};
      final replies = (ticket['replies'] is List) ? (ticket['replies'] as List) : [];
      final replyCtrl = TextEditingController();
      final scrollCtrl = ScrollController();
      String currentStatus = ticket['status'] ?? 'open';

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scrollCtrl.hasClients) {
          scrollCtrl.jumpTo(scrollCtrl.position.maxScrollExtent);
        }
      });

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setDState) => AlertDialog(
            title: Row(children: [
              const Icon(Icons.support_agent, color: kBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${ticket['ticketNo'] ?? ''}: ${ticket['subject'] ?? ''}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              statusChip(currentStatus),
            ]),
            content: SizedBox(
              width: math.min(700, MediaQuery.sizeOf(context).width * 0.95),
              height: math.min(520, MediaQuery.sizeOf(context).height * 0.8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Ticket header meta
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        'User: ${ticket['user']?['name'] ?? ''} (${ticket['user']?['email'] ?? 'No email'})',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                    DropdownButton<String>(
                      value: currentStatus,
                      items: const [
                        DropdownMenuItem(value: 'open', child: Text('Open')),
                        DropdownMenuItem(value: 'in_progress', child: Text('In Progress')),
                        DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                        DropdownMenuItem(value: 'closed', child: Text('Closed')),
                      ],
                      onChanged: (v) async {
                        if (v != null) {
                          try {
                            await ApiService.patch('/admin/support/tickets/$id/status', {'status': v});
                            setDState(() => currentStatus = v);
                            _fetchTickets();
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(content: Text('Failed to update status: $e'), backgroundColor: kRed),
                            );
                          }
                        }
                      },
                    ),
                  ]),
                ),
                const SizedBox(height: 12),

                // Original User Message
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F8FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFD6E4FF)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Original Complaint:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: kNavy)),
                    const SizedBox(height: 4),
                    Text('${ticket['message'] ?? ''}', style: const TextStyle(fontSize: 13)),
                  ]),
                ),
                const SizedBox(height: 12),

                // Replies List
                const Text('Conversation History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: replies.isEmpty
                      ? const Center(child: Text('No replies yet', style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.all(10),
                          itemCount: replies.length,
                          itemBuilder: (_, i) {
                            final r = replies[i];
                            final bool isAdmin = r['authorType'] == 'admin';
                            return Align(
                              alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                constraints: const BoxConstraints(maxWidth: 480),
                                decoration: BoxDecoration(
                                  color: isAdmin ? kBlue : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(
                                    isAdmin ? 'Admin Reply' : 'User',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: isAdmin ? Colors.white70 : Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${r['message'] ?? ''}',
                                    style: TextStyle(
                                      color: isAdmin ? Colors.white : Colors.black87,
                                      fontSize: 13,
                                    ),
                                  ),
                                ]),
                              ),
                            );
                          },
                        ),
                  ),
                ),
                const SizedBox(height: 10),

                // Reply Input
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: replyCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Type your official admin response...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _sendReply(id, replyCtrl, ctx),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _sendReply(id, replyCtrl, ctx),
                    icon: const Icon(Icons.send, size: 16),
                    label: const Text('Reply'),
                  ),
                ]),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close loading
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to load ticket: $e'), backgroundColor: kRed),
      );
    }
  }

  void _sendReply(String id, TextEditingController ctrl, BuildContext dialogCtx) async {
    final msg = ctrl.text.trim();
    if (msg.isEmpty) return;
    Navigator.pop(dialogCtx);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ApiService.post('/admin/support/tickets/$id/reply', {'message': msg});
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Reply sent successfully'), backgroundColor: kGreen),
      );
      _fetchTickets();
      _openTicketChat(id);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to send reply: $e'), backgroundColor: kRed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Filter Card
        card(
          'Support & Helpdesk Inbox ($_totalTickets Total)',
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 900;
              final searchField = TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search by Ticket No (e.g. TKT-1024)...',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _debounce.run(() {
                  if (!mounted) return;
                  setState(() => _page = 1);
                  _fetchTickets();
                }),
                onSubmitted: (_) {
                  setState(() => _page = 1);
                  _fetchTickets();
                },
              );

              final filterWidgets = [
                DropdownButton<String>(
                  value: _selectedStatus,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                    DropdownMenuItem(value: 'open', child: Text('Open')),
                    DropdownMenuItem(value: 'in_progress', child: Text('In Progress')),
                    DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                    DropdownMenuItem(value: 'closed', child: Text('Closed')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _selectedStatus = v;
                        _page = 1;
                      });
                      _fetchTickets();
                    }
                  },
                ),
                DropdownButton<String>(
                  value: _selectedPriority,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Priorities')),
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                    DropdownMenuItem(value: 'normal', child: Text('Normal')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _selectedPriority = v;
                        _page = 1;
                      });
                      _fetchTickets();
                    }
                  },
                ),
                DropdownButton<String>(
                  value: _selectedCategory,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Categories')),
                    DropdownMenuItem(value: 'payment', child: Text('Payment')),
                    DropdownMenuItem(value: 'game', child: Text('Game')),
                    DropdownMenuItem(value: 'account', child: Text('Account')),
                    DropdownMenuItem(value: 'bug', child: Text('Bug')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _selectedCategory = v;
                        _page = 1;
                      });
                      _fetchTickets();
                    }
                  },
                ),
                FilledButton.icon(
                  onPressed: () {
                    setState(() => _page = 1);
                    _fetchTickets();
                  },
                  icon: const Icon(Icons.filter_list, size: 16),
                  label: const Text('Filter'),
                ),
              ];

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    searchField,
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: filterWidgets,
                    ),
                  ],
                );
              }

              return Row(children: [
                Expanded(flex: 3, child: searchField),
                const SizedBox(width: 12),
                filterWidgets[0],
                const SizedBox(width: 12),
                filterWidgets[1],
                const SizedBox(width: 12),
                filterWidgets[2],
                const SizedBox(width: 12),
                filterWidgets[3],
              ]);
            },
          ),
        ),
        const SizedBox(height: 16),

        // Tickets Table Card
        card(
          'Support Tickets',
          _loading
              ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
              : _error != null
                  ? Center(
                      child: Column(children: [
                        Text('Error loading tickets: $_error', style: const TextStyle(color: kRed)),
                        const SizedBox(height: 8),
                        TextButton(onPressed: _fetchTickets, child: const Text('Retry')),
                      ]),
                    )
                  : _tickets.isEmpty
                      ? const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No support tickets found')))
                      : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('TICKET #')),
                                DataColumn(label: Text('USER')),
                                DataColumn(label: Text('SUBJECT')),
                                DataColumn(label: Text('CATEGORY')),
                                DataColumn(label: Text('PRIORITY')),
                                DataColumn(label: Text('STATUS')),
                                DataColumn(label: Text('REPLIES')),
                                DataColumn(label: Text('ACTIONS')),
                              ],
                              rows: [
                                for (var i = 0; i < _tickets.length; i++)
                                  DataRow(cells: [
                                    DataCell(Text('${_tickets[i]['ticketNo'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold))),
                                    DataCell(Text(
                                      _tickets[i]['user']?['name'] ?? _tickets[i]['user']?['email'] ?? 'Unknown',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    )),
                                    DataCell(Text('${_tickets[i]['subject'] ?? ''}')),
                                    DataCell(Text('${_tickets[i]['category']?.toUpperCase() ?? ''}')),
                                    DataCell(statusChip('${_tickets[i]['priority'] ?? 'normal'}')),
                                    DataCell(statusChip('${_tickets[i]['status'] ?? 'open'}')),
                                    DataCell(Text('${_tickets[i]['replyCount'] ?? 0}')),
                                    DataCell(
                                      FilledButton.tonal(
                                        onPressed: () => _openTicketChat('${_tickets[i]['id'] ?? _tickets[i]['_id'] ?? ''}'),
                                        child: const Text('View & Reply'),
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
                              Text('Page $_page of $_totalPages ($_totalTickets tickets)', style: const TextStyle(color: Colors.grey)),
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                OutlinedButton(
                                  onPressed: _page > 1 ? () { setState(() => _page--); _fetchTickets(); } : null,
                                  child: const Text('Previous'),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: _page < _totalPages ? () { setState(() => _page++); _fetchTickets(); } : null,
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
