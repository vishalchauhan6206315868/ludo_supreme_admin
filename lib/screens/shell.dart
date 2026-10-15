import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'dashboard_screen.dart';
import 'users_screen.dart';
import 'games_screen.dart';
import 'economy_screen.dart';
import 'banners_screen.dart';
import 'support_screen.dart';
import 'admins_screen.dart';
import 'settings_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';

class _Item {
  final String title;
  final IconData icon;
  final bool superAdminOnly;
  const _Item(this.title, this.icon, {this.superAdminOnly = false});
}

const _allItems = <_Item>[
  _Item('Dashboard', Icons.home_rounded),
  _Item('Users', Icons.people_outline),
  _Item('Games', Icons.sports_esports_outlined),
  _Item('Coins & Economy', Icons.monetization_on_outlined),
  _Item('Banners & Events', Icons.campaign_outlined),
  _Item('Support / Complaints', Icons.support_agent),
  _Item('Admin & Audit Logs', Icons.admin_panel_settings_outlined, superAdminOnly: true),
  _Item('Settings', Icons.settings_outlined),
  _Item('Notifications', Icons.notifications_none),
  _Item('Profile', Icons.person_outline),
];

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;

  @override
  void initState() {
    super.initState();
    ApiService.fetchProfile().then((_) {
      if (mounted) setState(() {});
    });
  }

  List<_Item> get _items {
    return _allItems.where((it) {
      if (!it.superAdminOnly) return true;
      return ApiService.isSuperAdmin || ApiService.demo;
    }).toList();
  }

  Widget _getScreen(String title) {
    switch (title) {
      case 'Dashboard':
        return const DashboardScreen();
      case 'Users':
        return const UsersScreen();
      case 'Games':
        return const GamesScreen();
      case 'Coins & Economy':
        return const EconomyScreen();
      case 'Banners & Events':
        return const BannersScreen();
      case 'Support / Complaints':
        return const SupportScreen();
      case 'Admin & Audit Logs':
        return const AdminsScreen();
      case 'Settings':
        return const SettingsScreen();
      case 'Notifications':
        return const NotificationsScreen();
      case 'Profile':
        return const ProfileScreen();
      default:
        return const DashboardScreen();
    }
  }

  Widget _sidebar(bool drawer) {
    final items = _items;
    return Container(
      width: 250,
      color: kNavy,
      child: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/icons/admin_logo.png',
                  width: 38,
                  height: 38,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text.rich(TextSpan(children: [
                  TextSpan(text: 'Ludo', style: TextStyle(color: Colors.white)),
                  TextSpan(text: 'Supreme', style: TextStyle(color: Color(0xFF4DA3FF))),
                ]), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                Text(
                  ApiService.demo ? 'DEMO MODE' : 'ADMIN PANEL',
                  style: TextStyle(
                    color: ApiService.demo ? Colors.amber : Colors.white60,
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ]),
            ]),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) {
                final sel = i == index;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  child: Material(
                    color: sel ? kBlue : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: ListTile(
                      dense: true,
                      leading: Icon(items[i].icon, color: Colors.white, size: 20),
                      title: Text(items[i].title, style: const TextStyle(color: Colors.white, fontSize: 13)),
                      onTap: () {
                        setState(() => index = i);
                        if (drawer) Navigator.pop(context);
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              const Text('v1.2.0', style: TextStyle(color: Colors.white54, fontSize: 12)),
              const Spacer(),
              Icon(Icons.circle, color: ApiService.demo ? Colors.amber : kGreen, size: 10),
              const SizedBox(width: 6),
              Text(
                ApiService.demo ? 'Offline Demo' : 'Server Online',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _demoBanner() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF4D6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(children: [
        const Icon(Icons.science_outlined, size: 16, color: Color(0xFF8A6100)),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'Demo mode: sample data, koi backend call nahi',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: Color(0xFF8A6100), fontWeight: FontWeight.w600),
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          onPressed: () async {
            await ApiService.logout();
            if (!mounted) return;
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          },
          child: const Text('Exit Demo', style: TextStyle(fontSize: 12)),
        ),
      ]),
    );
  }

  Widget _topBar(bool wide) {
    final admin = ApiService.currentAdmin ?? {};
    final adminName = admin['name'] ?? (ApiService.demo ? 'Demo Admin' : 'Admin');
    final adminRole = admin['role'] ?? (ApiService.demo ? 'SuperAdmin' : 'Admin');

    return Container(
      height: 64,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        if (!wide)
          Builder(
            builder: (c) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(c).openDrawer(),
            ),
          ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            _items[index.clamp(0, math.max(0, _items.length - 1))].title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const Spacer(),
        PopupMenuButton<String>(
          onSelected: (val) async {
            if (val == 'profile') {
              final pIndex = _items.indexWhere((it) => it.title == 'Profile');
              if (pIndex != -1) setState(() => index = pIndex);
            } else if (val == 'logout') {
              await ApiService.logout();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            } else if (val == 'logout_all') {
              await ApiService.logoutAll();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'profile',
              child: Row(children: [
                Icon(Icons.person_outline, size: 18),
                SizedBox(width: 8),
                Text('Admin Profile'),
              ]),
            ),
            const PopupMenuItem(
              value: 'logout',
              child: Row(children: [
                Icon(Icons.logout, size: 18),
                SizedBox(width: 8),
                Text('Log Out'),
              ]),
            ),
            const PopupMenuItem(
              value: 'logout_all',
              child: Row(children: [
                Icon(Icons.power_settings_new, size: 18, color: kRed),
                SizedBox(width: 8),
                Text('Log Out All Devices', style: TextStyle(color: kRed)),
              ]),
            ),
          ],
          child: Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: kBlue.withValues(alpha: 0.12),
              child: const Icon(Icons.person, color: kBlue, size: 20),
            ),
            if (wide) ...[
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(adminName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(adminRole.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
            const Icon(Icons.keyboard_arrow_down, size: 18),
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 900;
      final items = _items;
      final safeIndex = index.clamp(0, items.length - 1);
      final body = _getScreen(items[safeIndex].title);

      return Scaffold(
        drawer: wide ? null : Drawer(child: _sidebar(true)),
        body: Row(children: [
          if (wide) _sidebar(false),
          Expanded(
            child: Column(children: [
              _topBar(wide),
              if (ApiService.demo) _demoBanner(),
              Expanded(child: body),
            ]),
          ),
        ]),
      );
    });
  }
}
