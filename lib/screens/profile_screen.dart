import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loading = false;
  bool _fetchingProfile = false;
  String? _passwordError;
  String? _passwordSuccess;
  Map<String, dynamic>? _adminData;

  @override
  void initState() {
    super.initState();
    _adminData = ApiService.currentAdmin;
    _refreshProfile();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _refreshProfile() async {
    setState(() => _fetchingProfile = true);
    try {
      await ApiService.fetchProfile();
      if (mounted) {
        setState(() {
          _adminData = ApiService.currentAdmin;
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _fetchingProfile = false);
    }
  }

  Future<void> _changePassword() async {
    final curr = _currentPasswordController.text;
    final next = _newPasswordController.text;
    final conf = _confirmPasswordController.text;

    if (curr.isEmpty) {
      setState(() => _passwordError = 'Please enter your current password');
      return;
    }
    if (next.length < 10) {
      setState(() => _passwordError = 'New password must be at least 10 characters long');
      return;
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(next) || !RegExp(r'\d').hasMatch(next)) {
      setState(() => _passwordError = 'New password must contain both letters and numbers');
      return;
    }
    if (next != conf) {
      setState(() => _passwordError = 'Passwords do not match');
      return;
    }
    if (curr == next) {
      setState(() => _passwordError = 'New password must be different from current password');
      return;
    }

    setState(() {
      _loading = true;
      _passwordError = null;
      _passwordSuccess = null;
    });

    try {
      await ApiService.changePassword(curr, next);
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      setState(() {
        _passwordSuccess = 'Password changed successfully! All other active sessions have been signed out.';
      });
    } catch (e) {
      setState(() => _passwordError = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _confirmLogoutAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out Everywhere?'),
        content: const Text(
          'This will revoke authentication tokens for this account across all devices and web browsers. You will need to log back in.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () async {
              Navigator.pop(ctx);
              await ApiService.logoutAll();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Sign Out All Devices'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = _adminData ?? {};
    final name = admin['name'] ?? 'Administrator';
    final email = admin['email'] ?? 'admin@ludosupreme.com';
    final role = (admin['role'] ?? 'admin').toString().toUpperCase();
    final createdAt = admin['createdAt'] != null
        ? admin['createdAt'].toString().substring(0, math.min(10, admin['createdAt'].toString().length))
        : '';
    final lastLogin = admin['lastLogin'] != null
        ? admin['lastLogin'].toString().substring(0, math.min(16, admin['lastLogin'].toString().length)).replaceFirst('T', ' ')
        : 'Active Session';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Profile Summary Card
        card(
          'Operator Profile Details',
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 600;

              final infoContent = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: role == 'SUPERADMIN' ? kPurple.withValues(alpha: 0.15) : kBlue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          role,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: role == 'SUPERADMIN' ? kPurple : kBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(email, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 16, runSpacing: 4, children: [
                    Text('Member Since: $createdAt', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    Text('Last Active: $lastLogin', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ]),
                ],
              );

              final refreshButton = IconButton(
                icon: _fetchingProfile
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh),
                tooltip: 'Refresh Profile Data',
                onPressed: _fetchingProfile ? null : _refreshProfile,
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: kBlue.withValues(alpha: 0.15),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'A',
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: kBlue),
                          ),
                        ),
                        refreshButton,
                      ],
                    ),
                    const SizedBox(height: 16),
                    infoContent,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: kBlue.withValues(alpha: 0.15),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'A',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: kBlue),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(child: infoContent),
                  refreshButton,
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 20),

        // Change Password Card
        card(
          'Security & Password Management',
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text(
              'Update your account password. Strong passwords contain at least 10 characters with letters and numbers.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(children: [
                TextField(
                  controller: _currentPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Current Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New Password (Min 10 characters)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.vpn_key_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm New Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.check_circle_outline),
                  ),
                ),
                if (_passwordError != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kRed.withValues(alpha: 0.3)),
                    ),
                    child: Text(_passwordError!, style: const TextStyle(color: kRed, fontSize: 13)),
                  ),
                ],
                if (_passwordSuccess != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kGreen.withValues(alpha: 0.3)),
                    ),
                    child: Text(_passwordSuccess!, style: const TextStyle(color: kGreen, fontSize: 13)),
                  ),
                ],
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _changePassword,
                    icon: _loading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_outlined),
                    label: const Text('Update Password'),
                  ),
                ),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 20),

        // Session Invalidation Card
        card(
          'Active Sessions & Device Management',
          Row(children: [
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Revoke All Active Sessions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                SizedBox(height: 4),
                Text(
                  'If you suspect unauthorized access or logged in from a shared computer, you can invalidate all issued tokens instantly.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ]),
            ),
            const SizedBox(width: 16),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: kRed, side: const BorderSide(color: kRed)),
              onPressed: _confirmLogoutAll,
              icon: const Icon(Icons.logout, size: 16),
              label: const Text('Logout All Devices'),
            ),
          ]),
        ),
      ]),
    );
  }
}
