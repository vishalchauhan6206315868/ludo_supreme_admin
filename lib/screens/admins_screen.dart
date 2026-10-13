import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../utils/safe.dart';

class AdminsScreen extends StatefulWidget {
  const AdminsScreen({super.key});

  @override
  State<AdminsScreen> createState() => _AdminsScreenState();
}

class _AdminsScreenState extends State<AdminsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Admins state
  bool _loadingAdmins = false;
  String? _adminsError;
  List<dynamic> _admins = [];
  int _adminsPage = 1;
  final int _adminsLimit = 15;
  int _adminsTotalPages = 1;
  int _adminsTotalCount = 0;

  // Audit Logs state
  bool _loadingLogs = false;
  String? _logsError;
  List<dynamic> _logs = [];
  final _actionFilterController = TextEditingController();
  int _logsPage = 1;
  final int _logsLimit = 20;
  int _logsTotalPages = 1;
  int _logsTotalCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (ApiService.isSuperAdmin) {
      _fetchAdmins();
      _fetchLogs();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _actionFilterController.dispose();
    super.dispose();
  }

  int _adminsReq = 0;
  Future<void> _fetchAdmins() async {
    final r = ++_adminsReq;
    setState(() {
      _loadingAdmins = true;
      _adminsError = null;
    });

    try {
      final res = await ApiService.get('/admin/admins', query: {
        'page': _adminsPage,
        'limit': _adminsLimit,
      });
      if (!mounted || r != _adminsReq) return;

      final data = (res is Map && res['data'] is Map) ? res['data'] as Map : {};
      final list = (data['admins'] is List) ? data['admins'] as List : [];
      final pagination = (data['pagination'] is Map) ? data['pagination'] as Map : {};

      setState(() {
        _admins = list;
        _adminsPage = (pagination['page'] is num) ? (pagination['page'] as num).toInt() : _adminsPage;
        _adminsTotalPages = (pagination['totalPages'] is num) ? math.max(1, (pagination['totalPages'] as num).toInt()) : 1;
        _adminsTotalCount = (pagination['total'] is num) ? (pagination['total'] as num).toInt() : list.length;
      });
    } catch (e) {
      if (mounted && r == _adminsReq) setState(() => _adminsError = '$e');
    } finally {
      if (mounted && r == _adminsReq) setState(() => _loadingAdmins = false);
    }
  }

  int _logsReq = 0;
  Future<void> _fetchLogs() async {
    final r = ++_logsReq;
    setState(() {
      _loadingLogs = true;
      _logsError = null;
    });

    try {
      final query = <String, dynamic>{
        'page': _logsPage,
        'limit': _logsLimit,
      };
      final act = _actionFilterController.text.trim();
      if (act.isNotEmpty) query['action'] = act;

      final res = await ApiService.get('/admin/audit-logs', query: query);
      if (!mounted || r != _logsReq) return;
      final data = (res is Map && res['data'] is Map) ? res['data'] as Map : {};
      final list = (data['logs'] is List) ? data['logs'] as List : [];
      final pagination = (data['pagination'] is Map) ? data['pagination'] as Map : {};

      setState(() {
        _logs = list;
        _logsPage = (pagination['page'] is num) ? (pagination['page'] as num).toInt() : _logsPage;
        _logsTotalPages = (pagination['totalPages'] is num) ? math.max(1, (pagination['totalPages'] as num).toInt()) : 1;
        _logsTotalCount = (pagination['total'] is num) ? (pagination['total'] as num).toInt() : list.length;
      });
    } catch (e) {
      if (mounted && r == _logsReq) setState(() => _logsError = '$e');
    } finally {
      if (mounted && r == _logsReq) setState(() => _loadingLogs = false);
    }
  }

  void _showCreateAdminDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String role = 'admin';
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.person_add_alt_1, color: kBlue),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Create New Administrator',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ]),
          content: SizedBox(
            width: math.min(440, MediaQuery.sizeOf(context).width * 0.9),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full Name (2-50 characters)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Official Email Address',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password (Min 10 chars, letter + digit)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(
                    labelText: 'Admin Role & Privileges',
                    border: OutlineInputBorder(),
                  ),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'admin', child: Text('Standard Admin (Operations & Support)', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'superadmin', child: Text('Super Admin (Full Root Permissions)', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setDState(() => role = v!),
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
                      final name = nameCtrl.text.trim();
                      final email = emailCtrl.text.trim();
                      final pass = passCtrl.text;

                      if (name.length < 2 || name.length > 50) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Name must be 2-50 characters'), backgroundColor: kRed),
                        );
                        return;
                      }
                      if (!email.contains('@') || !email.contains('.')) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid email address'), backgroundColor: kRed),
                        );
                        return;
                      }
                      if (pass.length < 10) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Password must be at least 10 characters'), backgroundColor: kRed),
                        );
                        return;
                      }

                      setDState(() => isSubmitting = true);
                      final messenger = ScaffoldMessenger.of(context);

                      try {
                        await ApiService.post('/admin/admins', {
                          'name': name,
                          'email': email,
                          'password': pass,
                          'role': role,
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (!mounted) return;
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Administrator created successfully!'), backgroundColor: kGreen),
                        );
                        _fetchAdmins();
                      } catch (e) {
                        setDState(() => isSubmitting = false);
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(content: Text('Failed to create admin: $e'), backgroundColor: kRed),
                        );
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Create Account'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmToggleAdminStatus(Map admin) {
    final currentActive = admin['isActive'] != false;
    final targetActive = !currentActive;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          title: Text(targetActive ? 'Activate Admin Account?' : 'Deactivate Admin Account?'),
          content: Text(
            targetActive
                ? 'Are you sure you want to reactivate access for ${admin['name']} (${admin['email']})?'
                : 'Deactivating ${admin['name']} (${admin['email']}) will immediately revoke their access and invalidate all existing sessions.',
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
                      setDState(() => isSubmitting = true);
                      final messenger = ScaffoldMessenger.of(context);

                      try {
                        await ApiService.patch('/admin/admins/${admin['id'] ?? admin['_id']}/status', {
                          'isActive': targetActive,
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Admin account ${targetActive ? 'activated' : 'deactivated'} successfully'),
                            backgroundColor: kGreen,
                          ),
                        );
                        _fetchAdmins();
                      } catch (e) {
                        setDState(() => isSubmitting = false);
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(content: Text('Failed to update status: $e'), backgroundColor: kRed),
                        );
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(targetActive ? 'Activate' : 'Deactivate'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!ApiService.isSuperAdmin) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE6ECF5)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.shield_outlined, size: 54, color: kOrange),
            const SizedBox(height: 16),
            const Text('Super Admin Privileges Required', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Admin user management and system audit trail access are strictly restricted to Super Administrators. Your current role does not have authorization to view or modify administrative credentials.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, height: 1.4),
            ),
            const SizedBox(height: 20),
            statusChip('Current Role: ${ApiService.currentAdmin?['role'] ?? 'Admin'}'),
          ]),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: kBlue,
            indicatorColor: kBlue,
            tabs: const [
              Tab(icon: Icon(Icons.admin_panel_settings), text: 'Admin Accounts'),
              Tab(icon: Icon(Icons.history_edu), text: 'System Audit Logs'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildAdminsTab(),
              _buildAuditLogsTab(),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildAdminsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        card(
          'Administrators Overview ($_adminsTotalCount Total)',
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Manage platform staff credentials, roles, and authorization states.',
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
              FilledButton.icon(
                onPressed: _showCreateAdminDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Administrator'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        card(
          'Staff Accounts Directory',
          _loadingAdmins
              ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
              : _adminsError != null
                  ? Center(
                      child: Column(children: [
                        Text('Failed to load admins: $_adminsError', style: const TextStyle(color: kRed)),
                        const SizedBox(height: 8),
                        TextButton(onPressed: _fetchAdmins, child: const Text('Retry')),
                      ]),
                    )
                  : _admins.isEmpty
                      ? const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No administrator accounts found')))
                      : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('#')),
                                DataColumn(label: Text('NAME')),
                                DataColumn(label: Text('EMAIL')),
                                DataColumn(label: Text('ROLE')),
                                DataColumn(label: Text('STATUS')),
                                DataColumn(label: Text('LAST LOGIN')),
                                DataColumn(label: Text('CREATED')),
                                DataColumn(label: Text('ACTIONS')),
                              ],
                              rows: [
                                for (var i = 0; i < _admins.length; i++)
                                  DataRow(cells: [
                                    DataCell(Text('${(_adminsPage - 1) * _adminsLimit + i + 1}')),
                                    DataCell(Row(children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor: _admins[i]['role'] == 'superadmin' ? kPurple.withValues(alpha: 0.15) : kBlue.withValues(alpha: 0.15),
                                        child: Text(
                                          initialOf(_admins[i]['name'], 'A'),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: _admins[i]['role'] == 'superadmin' ? kPurple : kBlue,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text('${_admins[i]['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                    ])),
                                    DataCell(Text('${_admins[i]['email'] ?? ''}')),
                                    DataCell(Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _admins[i]['role'] == 'superadmin' ? kPurple.withValues(alpha: 0.12) : kBlue.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${_admins[i]['role'] ?? 'admin'}'.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: _admins[i]['role'] == 'superadmin' ? kPurple : kBlue,
                                        ),
                                      ),
                                    )),
                                    DataCell(statusChip(_admins[i]['isActive'] != false ? 'Active' : 'Blocked')),
                                    DataCell(Text(
                                      _admins[i]['lastLogin'] != null
                                          ? _admins[i]['lastLogin'].toString().substring(0, math.min(16, _admins[i]['lastLogin'].toString().length))
                                          : 'Never',
                                    )),
                                    DataCell(Text(
                                      _admins[i]['createdAt'] != null
                                          ? _admins[i]['createdAt'].toString().substring(0, math.min(10, _admins[i]['createdAt'].toString().length))
                                          : '',
                                    )),
                                    DataCell(
                                      IconButton(
                                        icon: Icon(
                                          _admins[i]['isActive'] != false ? Icons.lock_outline : Icons.lock_open,
                                          size: 20,
                                          color: _admins[i]['isActive'] != false ? kRed : kGreen,
                                        ),
                                        tooltip: _admins[i]['isActive'] != false ? 'Deactivate Account' : 'Reactivate Account',
                                        onPressed: () => _confirmToggleAdminStatus(_admins[i]),
                                      ),
                                    ),
                                  ]),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              Text('Page $_adminsPage of $_adminsTotalPages ($_adminsTotalCount admins)', style: const TextStyle(color: Colors.grey)),
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                OutlinedButton(
                                  onPressed: _adminsPage > 1 ? () { setState(() => _adminsPage--); _fetchAdmins(); } : null,
                                  child: const Text('Previous'),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: _adminsPage < _adminsTotalPages ? () { setState(() => _adminsPage++); _fetchAdmins(); } : null,
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

  Widget _buildAuditLogsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        card(
          'Security & Audit Trail Filter',
          Row(children: [
            Expanded(
              child: TextField(
                controller: _actionFilterController,
                decoration: const InputDecoration(
                  hintText: 'Filter by Action (e.g. user.block, wallet.credit, admin.create)...',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) {
                  setState(() => _logsPage = 1);
                  _fetchLogs();
                },
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () {
                setState(() => _logsPage = 1);
                _fetchLogs();
              },
              icon: const Icon(Icons.filter_list, size: 16),
              label: const Text('Filter Logs'),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        card(
          'Immutable Security Event History',
          _loadingLogs
              ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
              : _logsError != null
                  ? Center(
                      child: Column(children: [
                        Text('Failed to load audit logs: $_logsError', style: const TextStyle(color: kRed)),
                        const SizedBox(height: 8),
                        TextButton(onPressed: _fetchLogs, child: const Text('Retry')),
                      ]),
                    )
                  : _logs.isEmpty
                      ? const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No audit log entries recorded')))
                      : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('#')),
                                DataColumn(label: Text('TIMESTAMP')),
                                DataColumn(label: Text('OPERATOR')),
                                DataColumn(label: Text('ACTION')),
                                DataColumn(label: Text('TARGET TYPE')),
                                DataColumn(label: Text('TARGET ID')),
                                DataColumn(label: Text('IP ADDRESS')),
                              ],
                              rows: [
                                for (var i = 0; i < _logs.length; i++)
                                  DataRow(cells: [
                                    DataCell(Text('${(_logsPage - 1) * _logsLimit + i + 1}')),
                                    DataCell(Text(
                                      _logs[i]['createdAt'] != null
                                          ? _logs[i]['createdAt'].toString().substring(0, math.min(19, _logs[i]['createdAt'].toString().length)).replaceFirst('T', ' ')
                                          : '',
                                      style: const TextStyle(fontSize: 12),
                                    )),
                                    DataCell(Text('${_logs[i]['adminEmail'] ?? 'System'}', style: const TextStyle(fontWeight: FontWeight.w600))),
                                    DataCell(Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.blueGrey.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${_logs[i]['action'] ?? ''}',
                                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                    )),
                                    DataCell(Text('${_logs[i]['targetType'] ?? '-'}')),
                                    DataCell(Text('${_logs[i]['targetId'] ?? '-'}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
                                    DataCell(Text('${_logs[i]['ip'] ?? '-'}', style: const TextStyle(color: Colors.grey, fontSize: 12))),
                                  ]),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              Text('Page $_logsPage of $_logsTotalPages ($_logsTotalCount audit events)', style: const TextStyle(color: Colors.grey)),
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                OutlinedButton(
                                  onPressed: _logsPage > 1 ? () { setState(() => _logsPage--); _fetchLogs(); } : null,
                                  child: const Text('Previous'),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: _logsPage < _logsTotalPages ? () { setState(() => _logsPage++); _fetchLogs(); } : null,
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
