import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../utils/safe.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<dynamic> _future;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// Missing value par invented default nahi, "—" dikhao.
  String _v(dynamic v, [String suffix = '']) => v == null ? '—' : '$v$suffix';

  void _loadSettings() {
    setState(() {
      _future = ApiService.get('/admin/settings');
    });
  }

  Widget _tile(String label, String value, [IconData? icon]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: Colors.grey),
            const SizedBox(width: 8),
          ],
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            flex: 3,
            child: SelectableText(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Informational Notice Card
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: kBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBlue.withValues(alpha: 0.25)),
          ),
          child: const Row(children: [
            Icon(Icons.info_outline, color: kBlue, size: 28),
            SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  'Environment & Server Driven Configuration',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kNavy),
                ),
                SizedBox(height: 4),
                Text(
                  'All core engine parameters, rate limits, and economy fee structures are enforced securely on the Node.js backend. In accordance with zero-trust architecture, settings are read-only in this console and must be modified via environment variables on the production server.',
                  style: TextStyle(fontSize: 12, color: Colors.black87, height: 1.3),
                ),
              ]),
            ),
          ]),
        ),

        FutureBuilder(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(60),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError || snapshot.data is! Map) {
              return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.error_outline, size: 48, color: kRed),
                  const SizedBox(height: 12),
                  Text('Failed to load system settings: ${snapshot.error}', style: const TextStyle(color: kRed)),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _loadSettings,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ]),
              );
            }

            final res = asMap(snapshot.data);
            final data = (res['data'] is Map) ? asMap(res['data']) : res;
            final game = asMap(data['game']);
            final economy = asMap(data['economy']);
            final admin = asMap(data['admin']);
            final rateLimit = asMap(data['rateLimit']);
            final db = asMap(data['database']);

            return LayoutBuilder(builder: (context, constraints) {
              final wide = constraints.maxWidth >= 960;
              return Column(children: [
                // System & Runtime
                card(
                  'Server Runtime & Deployment Environment',
                  Column(children: [
                    _tile('Environment Mode', '${data['environment'] ?? 'development'}'.toUpperCase(), Icons.cloud_outlined),
                    _tile('Backend Package Version', 'v${data['version'] ?? '1.0.0'}', Icons.tag),
                    _tile('Node.js Engine Version', '${data['node'] ?? 'N/A'}', Icons.terminal),
                    _tile('Operating Timezone', '${data['timezone'] ?? 'UTC'}', Icons.schedule),
                    _tile('API Base Endpoint', ApiService.baseUrl, Icons.link),
                  ]),
                ),
                const SizedBox(height: 16),

                // 2 Columns
                if (wide)
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: card(
                        'Game Engine Parameters',
                        Column(children: [
                          _tile('Turn Deadline Duration', _v(game['turnTimeoutSeconds'], ' seconds')),
                          _tile('Turn Timeout Grace', _v(game['turnTimeoutGraceMs'], ' ms')),
_tile('Match Duration Limit', _v(game['matchDurationSeconds'], ' seconds')),
_tile('Stale Match Sweeper', game['sweeperEnabled'] == true ? 'Enabled (every ${game['sweeperIntervalMs'] ?? '?'} ms)' : 'Disabled'),
                          _tile('Supported Modes', '2-Player, 4-Player Real-Time Ludo'),
                                                    _tile('Dice Roll Algorithm', 'Crypto-Random Fair Randomization'),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: card(
                        'Economy & Monetary Policies',
                        Column(children: [
                          _tile('Platform Rake / Commission', _v(economy['platformFeePercent'], '%')),
                          _tile('Welcome Registration Bonus', economy['signupBonusCoins'] == null ? '—' : formatCurrency(economy['signupBonusCoins'])),
_tile('Max Entry Fee', economy['maxEntryFee'] == null ? '—' : formatCurrency(economy['maxEntryFee'])),
_tile('Waiting Room Expiry', _v(economy['roomWaitingTtlMinutes'], ' minutes')),
                          _tile('Max Admin Coin Adjustment', admin['maxCoinAdjust'] == null ? '—' : formatCurrency(admin['maxCoinAdjust'])),
                          _tile('Wallet Ledger Type', 'Atomic ACID Transaction Journal'),
                        ]),
                      ),
                    ),
                  ])
                else ...[
                  card(
                    'Game Engine Parameters',
                    Column(children: [
                      _tile('Turn Deadline Duration', _v(game['turnTimeoutSeconds'], ' seconds')),
                      _tile('Turn Timeout Grace', _v(game['turnTimeoutGraceMs'], ' ms')),
_tile('Match Duration Limit', _v(game['matchDurationSeconds'], ' seconds')),
_tile('Stale Match Sweeper', game['sweeperEnabled'] == true ? 'Enabled (every ${game['sweeperIntervalMs'] ?? '?'} ms)' : 'Disabled'),
                      _tile('Supported Modes', '2-Player, 4-Player Real-Time Ludo'),
                                            _tile('Dice Roll Algorithm', 'Crypto-Random Fair Randomization'),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  card(
                    'Economy & Monetary Policies',
                    Column(children: [
                      _tile('Platform Rake / Commission', _v(economy['platformFeePercent'], '%')),
                      _tile('Welcome Registration Bonus', economy['signupBonusCoins'] == null ? '—' : formatCurrency(economy['signupBonusCoins'])),
_tile('Max Entry Fee', economy['maxEntryFee'] == null ? '—' : formatCurrency(economy['maxEntryFee'])),
_tile('Waiting Room Expiry', _v(economy['roomWaitingTtlMinutes'], ' minutes')),
                      _tile('Max Admin Coin Adjustment', admin['maxCoinAdjust'] == null ? '—' : formatCurrency(admin['maxCoinAdjust'])),
                      _tile('Wallet Ledger Type', 'Atomic ACID Transaction Journal'),
                    ]),
                  ),
                  const SizedBox(height: 16),
                ],

                const SizedBox(height: 16),

                // Security & Infrastructure
                if (wide)
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: card(
                        'Security & Rate Limiting Thresholds',
                        Column(children: [
                          _tile('Admin JWT Token Lifespan', _v(admin['jwtExpiresIn'])),
                          _tile('Dashboard Cache TTL', _v(admin['dashboardCacheSeconds'], ' seconds')),
                          _tile('Rate Limiting', rateLimit['enabled'] == false ? 'Disabled' : 'Enabled'),
_tile('Global IP Rate Limit', _v(rateLimit['globalPerMinute'], ' req / minute')),
_tile('Player Login Throttle', _v(rateLimit['authAttempts'], ' attempts / ${rateLimit['authWindowMinutes'] ?? 15} min')),
_tile('Admin Write Limit', _v(rateLimit['adminWritesPerMinute'], ' actions / minute')),
                          _tile('Admin Login Throttle', _v(rateLimit['adminAuthAttempts'], ' attempts / ${rateLimit['authWindowMinutes'] ?? 15} min')),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: card(
                        'Database & High Availability',
                        Column(children: [
                          _tile('Replica Set Required', db['requireReplicaSet'] == true ? 'Yes (Enabled)' : 'No (Single instance)'),
                          _tile('Mongoose Connection Pool', _v(db['maxPoolSize'], ' connections')),
                          _tile('Health Probe Endpoint', '/ready & /api/health'),
                        ]),
                      ),
                    ),
                  ])
                else ...[
                  card(
                    'Security & Rate Limiting Thresholds',
                    Column(children: [
                      _tile('Admin JWT Token Lifespan', _v(admin['jwtExpiresIn'])),
                      _tile('Dashboard Cache TTL', _v(admin['dashboardCacheSeconds'], ' seconds')),
                      _tile('Rate Limiting', rateLimit['enabled'] == false ? 'Disabled' : 'Enabled'),
_tile('Global IP Rate Limit', _v(rateLimit['globalPerMinute'], ' req / minute')),
_tile('Player Login Throttle', _v(rateLimit['authAttempts'], ' attempts / ${rateLimit['authWindowMinutes'] ?? 15} min')),
_tile('Admin Write Limit', _v(rateLimit['adminWritesPerMinute'], ' actions / minute')),
                      _tile('Admin Login Throttle', _v(rateLimit['adminAuthAttempts'], ' attempts / ${rateLimit['authWindowMinutes'] ?? 15} min')),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  card(
                    'Database & High Availability',
                    Column(children: [
                      _tile('Replica Set Required', db['requireReplicaSet'] == true ? 'Yes (Enabled)' : 'No (Single instance)'),
                      _tile('Mongoose Connection Pool', _v(db['maxPoolSize'], ' connections')),
                      _tile('Health Probe Endpoint', '/ready & /api/health'),
                    ]),
                  ),
                ],
              ]);
            });
          },
        ),
      ]),
    );
  }
}
