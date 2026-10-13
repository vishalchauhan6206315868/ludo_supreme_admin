import 'dart:math' as math;
import '../utils/safe.dart';
import 'api_exception.dart';

/// Demo mode ka in-memory "fake backend".
///
/// Real backend jaise hi response shape deta hai (`{success, data:{...}}`,
/// pagination, filters, detail endpoints, write actions) wahi yahan milta hai,
/// isliye har screen demo me bhi bina badlaav ke chalti hai.
class DemoData {
  static const Map<String, dynamic> demoAdmin = {
    'id': 'adm_demo',
    'name': 'Demo Admin',
    'email': 'demo@ludosupreme.com',
    'role': 'superadmin',
    'isActive': true,
    'lastLogin': '2026-10-12T07:45:00.000Z',
    'createdAt': '2026-09-01T09:00:00.000Z',
  };

  static _Store? _store;
  static void reset() => _store = null;
  static _Store get _s => _store ??= _seed();

  // ------------------------------------------------------------ router
  static dynamic handle(
    String method,
    String rawPath, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? body,
  }) {
    final q = <String, String>{};
    var path = rawPath;
    final qi = path.indexOf('?');
    if (qi >= 0) {
      try {
        q.addAll(Uri.splitQueryString(path.substring(qi + 1)));
      } catch (_) {}
      path = path.substring(0, qi);
    }
    query?.forEach((k, v) {
      if (v != null && '$v'.trim().isNotEmpty) q[k] = '$v';
    });

    final segs = path.split('/').where((s) => s.isNotEmpty).toList();
    final b = body ?? const <String, dynamic>{};
    final m = method.toUpperCase();
    if (segs.isEmpty || segs.first != 'admin') throw _notFound(m, path);
    final r = segs.skip(1).toList();
    final n = r.length;
    final s = _s;

    if (m == 'GET') {
      if (n == 1 && r[0] == 'dashboard') return _dashboard();
      if (n == 1 && r[0] == 'me') return _ok({'admin': demoAdmin});
      if (n == 1 && r[0] == 'users') return _users(q);
      if (n == 2 && r[0] == 'users') return _userDetail(r[1]);
      if (n == 1 && r[0] == 'games') return _games(q);
      if (n == 2 && r[0] == 'games') {
        return _ok({'game': _byId(s.games, r[1], 'Game')});
      }
      if (n == 2 && r[0] == 'support' && r[1] == 'tickets') return _tickets(q);
      if (n == 3 && r[0] == 'support' && r[1] == 'tickets') {
        return _ok({'ticket': _byId(s.tickets, r[2], 'Ticket')});
      }
      if (n == 1 && r[0] == 'banners') return _ok({'banners': s.banners});
      if (n == 2 && r[0] == 'economy' && r[1] == 'summary') return _economy();
      if (n == 2 && r[0] == 'reports' && r[1] == 'daily') {
        final days = math.min(90, math.max(1, int.tryParse(q['days'] ?? '') ?? 30));
        final rows = s.daily.length > days ? s.daily.sublist(s.daily.length - days) : s.daily;
        return _ok({'rows': rows});
      }
      if (n == 1 && r[0] == 'transactions') return _transactions(q);
      if (n == 1 && r[0] == 'settings') return _ok(_settings());
      if (n == 1 && r[0] == 'admins') return _paged(s.admins, q, 'admins', 10);
      if (n == 1 && r[0] == 'audit-logs') return _auditLogs(q);
    }

    if (m == 'POST') {
      if (n == 3 && r[0] == 'users' && r[2] == 'coins') return _adjustCoins(r[1], b);
      if (n == 1 && r[0] == 'admins') return _createAdmin(b);
      if (n == 4 && r[0] == 'support' && r[1] == 'tickets' && r[3] == 'reply') {
        return _replyTicket(r[2], b);
      }
      if (n == 1 && r[0] == 'banners') {
        final banner = <String, dynamic>{
          'id': 'bn_${DateTime.now().millisecondsSinceEpoch}',
          'title': '${b['title'] ?? 'Untitled'}',
          'subtitle': b['subtitle'],
          'imageUrl': _cleanUrl(b['imageUrl']),
          'linkUrl': _cleanUrl(b['linkUrl']),
          'type': b['type'] ?? 'banner',
          'priority': asNum(b['priority'], 10).toInt(),
          'isActive': b['isActive'] != false,
        };
        s.banners.insert(0, banner);
        _log('banner.create', 'banner', '${banner['id']}');
        return _ok({'banner': banner});
      }
      if (n == 1 && r[0] == 'change-password') {
        return _ok({'message': 'Password change simulated (demo mode)'});
      }
      if (n == 1 && r[0] == 'logout-all') return _ok({'message': 'Logged out (demo)'});
    }

    if (m == 'PATCH') {
      if (n == 3 && r[0] == 'users' && r[2] == 'status') {
        final u = _byId(s.users, r[1], 'User');
        final active = b['isActive'] != false;
        u['isActive'] = active;
        u['status'] = active ? 'Active' : 'Blocked';
        _log(active ? 'user.unblock' : 'user.block', 'user', r[1]);
        return _ok({'user': u});
      }
      if (n == 3 && r[0] == 'admins' && r[2] == 'status') {
        if (r[1] == '${demoAdmin['id']}') {
          throw ApiException('You cannot deactivate your own account', statusCode: 400);
        }
        final a = _byId(s.admins, r[1], 'Admin');
        a['isActive'] = b['isActive'] != false;
        _log(a['isActive'] == true ? 'admin.activate' : 'admin.deactivate', 'admin', r[1]);
        return _ok({'admin': a});
      }
      if (n == 4 && r[0] == 'support' && r[1] == 'tickets' && r[3] == 'status') {
        final t = _byId(s.tickets, r[2], 'Ticket');
        t['status'] = '${b['status'] ?? t['status']}';
        _log('ticket.status', 'ticket', r[2]);
        return _ok({'ticket': t});
      }
      if (n == 2 && r[0] == 'banners') {
        final bn = _byId(s.banners, r[1], 'Banner');
        for (final k in const ['title', 'subtitle', 'type', 'isActive']) {
          if (b.containsKey(k)) bn[k] = b[k];
        }
        if (b.containsKey('imageUrl')) bn['imageUrl'] = _cleanUrl(b['imageUrl']);
        if (b.containsKey('linkUrl')) bn['linkUrl'] = _cleanUrl(b['linkUrl']);
        if (b.containsKey('priority')) bn['priority'] = asNum(b['priority'], 10).toInt();
        _log('banner.update', 'banner', r[1]);
        return _ok({'banner': bn});
      }
    }

    if (m == 'DELETE') {
      if (n == 2 && r[0] == 'banners') {
        final bn = _byId(s.banners, r[1], 'Banner');
        s.banners.remove(bn);
        _log('banner.delete', 'banner', r[1]);
        return _ok({'deleted': true});
      }
    }

    throw _notFound(m, path);
  }

  // ----------------------------------------------------------- helpers
  static Map<String, dynamic> _ok(dynamic data) =>
      <String, dynamic>{'success': true, 'data': data is Map ? asMap(data) : data};

  static ApiException _notFound(String m, String path) =>
      ApiException('Demo mode: "$m $path" is not simulated', statusCode: 404);

  static ApiException _bad(String msg) => ApiException(msg, statusCode: 400);

  static String? _cleanUrl(dynamic v) {
    final s = '${v ?? ''}'.trim();
    return s.isEmpty ? null : s;
  }

  static Map<String, dynamic> _byId(List<Map<String, dynamic>> list, String id, String what) {
    for (final e in list) {
      if ('${e['id']}' == id) return e;
    }
    throw ApiException('$what not found', statusCode: 404);
  }

  static Map<String, dynamic> _paged(
    List<Map<String, dynamic>> items,
    Map<String, String> q,
    String key,
    int defaultLimit,
  ) {
    final limit = math.min(100, math.max(1, int.tryParse(q['limit'] ?? '') ?? defaultLimit));
    final total = items.length;
    final totalPages = math.max(1, (total / limit).ceil());
    final page = math.min(totalPages, math.max(1, int.tryParse(q['page'] ?? '') ?? 1));
    final slice = items.skip((page - 1) * limit).take(limit).toList();
    return _ok(<String, dynamic>{
      key: slice,
      'pagination': <String, dynamic>{
        'page': page,
        'limit': limit,
        'total': total,
        'totalPages': totalPages,
      },
    });
  }

  static bool _has(dynamic v, String needle) => '$v'.toLowerCase().contains(needle.toLowerCase());

  static void _log(String action, String targetType, String targetId) {
    _s.logs.insert(0, <String, dynamic>{
      'id': 'log_${DateTime.now().microsecondsSinceEpoch}',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'adminEmail': demoAdmin['email'],
      'action': action,
      'targetType': targetType,
      'targetId': targetId,
      'ip': '127.0.0.1',
    });
  }

  // --------------------------------------------------------- endpoints
  static Map<String, dynamic> _users(Map<String, String> q) {
    var list = List<Map<String, dynamic>>.of(_s.users);
    final search = (q['search'] ?? '').trim();
    if (search.isNotEmpty) {
      list = list
          .where((u) => _has(u['name'], search) || _has(u['email'], search) || _has(u['username'], search))
          .toList();
    }
    final st = q['status'];
    if (st == 'active') list = list.where((u) => u['isActive'] != false).toList();
    if (st == 'blocked') list = list.where((u) => u['isActive'] == false).toList();
    final sort = q['sort'] ?? 'newest';
    if (sort == 'oldest') {
      list = list.reversed.toList();
    } else if (sort == 'name') {
      list.sort((a, b) => '${a['name']}'.toLowerCase().compareTo('${b['name']}'.toLowerCase()));
    }
    return _paged(list, q, 'users', 15);
  }

  static Map<String, dynamic> _userDetail(String id) {
    final u = _byId(_s.users, id, 'User');
    final txs = _s.transactions.where((t) => '${asMap(t['user'])['id']}' == id).take(10).toList();
    final games = <Map<String, dynamic>>[];
    for (final g in _s.games) {
      final players = asList(g['players']);
      for (final p in players) {
        if (asMap(p)['name'] == u['name']) {
          final pm = asMap(p);
          games.add(<String, dynamic>{
            'roomCode': g['roomCode'],
            'mode': g['mode'] == 'twoPlayer' ? '2 Player' : '4 Player',
            'status': g['status'],
            'prizeEarned': pm['prizeEarned'],
            'outcome': pm['outcome'],
          });
          break;
        }
      }
      if (games.length >= 10) break;
    }
    return _ok({'user': u, 'recentTransactions': txs, 'recentGames': games});
  }

  static Map<String, dynamic> _games(Map<String, String> q) {
    var list = List<Map<String, dynamic>>.of(_s.games);
    final room = (q['roomCode'] ?? '').trim();
    if (room.isNotEmpty) list = list.where((g) => _has(g['roomCode'], room)).toList();
    if (q['status'] != null) list = list.where((g) => g['status'] == q['status']).toList();
    if (q['mode'] != null) list = list.where((g) => g['mode'] == q['mode']).toList();
    final res = _paged(list, q, 'games', 15);
    final data = asMap(res['data']);
    data['games'] = asList(data['games']).map((g) => Map<String, dynamic>.from(asMap(g))..remove('moves')).toList();
    return _ok(data);
  }

  static Map<String, dynamic> _tickets(Map<String, String> q) {
    var list = List<Map<String, dynamic>>.of(_s.tickets);
    final no = (q['ticketNo'] ?? '').trim();
    if (no.isNotEmpty) list = list.where((t) => _has(t['ticketNo'], no)).toList();
    for (final k in const ['status', 'priority', 'category']) {
      final v = q[k];
      if (v != null) list = list.where((t) => t[k] == v).toList();
    }
    return _paged(list, q, 'tickets', 15);
  }

  static Map<String, dynamic> _transactions(Map<String, String> q) {
    var list = List<Map<String, dynamic>>.of(_s.transactions);
    if (q['type'] != null) list = list.where((t) => t['type'] == q['type']).toList();
    if (q['source'] != null) list = list.where((t) => t['source'] == q['source']).toList();
    return _paged(list, q, 'transactions', 15);
  }

  static Map<String, dynamic> _auditLogs(Map<String, String> q) {
    var list = List<Map<String, dynamic>>.of(_s.logs);
    final act = (q['action'] ?? '').trim();
    if (act.isNotEmpty) list = list.where((l) => _has(l['action'], act)).toList();
    return _paged(list, q, 'logs', 20);
  }

  static Map<String, dynamic> _adjustCoins(String id, Map<String, dynamic> b) {
    final s = _s;
    final user = _byId(s.users, id, 'User');
    final key = '${b['idempotencyKey'] ?? ''}';
    if (key.isNotEmpty && s.coinResults.containsKey(key)) {
      return s.coinResults[key]!; // duplicate submit: dobara apply nahi hoga
    }
    final amt = asNum(b['amount']).toInt();
    if (amt <= 0 || amt > 100000) throw _bad('Amount must be between 1 and 100000');
    final reason = '${b['reason'] ?? ''}'.trim();
    if (reason.length < 3) throw _bad('Reason must be at least 3 characters');
    final credit = b['type'] != 'debit';
    final before = asNum(user['coins']).toInt();
    if (!credit && amt > before) throw _bad('Insufficient balance for debit');
    final after = credit ? before + amt : before - amt;
    user['coins'] = after;
    s.transactions.insert(0, <String, dynamic>{
      'id': 'tx_${DateTime.now().microsecondsSinceEpoch}',
      'user': <String, dynamic>{'id': user['id'], 'name': user['name'], 'email': user['email']},
      'type': credit ? 'credit' : 'debit',
      'amount': amt,
      'source': 'admin',
      'balanceBefore': before,
      'balanceAfter': after,
      'description': 'Admin adjustment: $reason',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });
    _log('user.coins.${credit ? 'credit' : 'debit'}', 'user', id);
    final res = _ok({'balance': after});
    if (key.isNotEmpty) s.coinResults[key] = res;
    return res;
  }

  static Map<String, dynamic> _createAdmin(Map<String, dynamic> b) {
    final email = '${b['email'] ?? ''}'.trim().toLowerCase();
    final name = '${b['name'] ?? ''}'.trim();
    if (name.isEmpty || !email.contains('@')) throw _bad('Valid name and email are required');
    if (_s.admins.any((a) => '${a['email']}'.toLowerCase() == email)) {
      throw ApiException('An admin with this email already exists', statusCode: 409);
    }
    final admin = <String, dynamic>{
      'id': 'adm_${DateTime.now().millisecondsSinceEpoch}',
      'name': name,
      'email': email,
      'role': b['role'] == 'superadmin' ? 'superadmin' : 'admin',
      'isActive': true,
      'lastLogin': null,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
    _s.admins.add(admin);
    _log('admin.create', 'admin', '${admin['id']}');
    return _ok({'admin': admin});
  }

  static Map<String, dynamic> _replyTicket(String id, Map<String, dynamic> b) {
    final t = _byId(_s.tickets, id, 'Ticket');
    final msg = '${b['message'] ?? ''}'.trim();
    if (msg.isEmpty) throw _bad('Reply message is required');
    final replies = asList(t['replies']).toList();
    replies.add(<String, dynamic>{
      'authorType': 'admin',
      'message': msg,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });
    t['replies'] = replies;
    t['replyCount'] = replies.length;
    if (t['status'] == 'open') t['status'] = 'in_progress';
    _log('ticket.reply', 'ticket', id);
    return _ok({'ticket': t});
  }

  static Map<String, dynamic> _economy() {
    final s = _s;
    num sumVol = 0, sumRev = 0;
    for (final d in s.daily) {
      sumVol += asNum(d['coinVolume']);
      sumRev += asNum(d['platformRevenue']);
    }
    return _ok(<String, dynamic>{
      'coinsInCirculation': 1842650,
      'wallets': 12458,
      'last30Days': <String, dynamic>{
        'flows': <Map<String, dynamic>>[
          {'type': 'credit', 'source': 'game_reward', 'count': 6120, 'amount': 412300},
          {'type': 'credit', 'source': 'bonus', 'count': 1840, 'amount': 92000},
          {'type': 'credit', 'source': 'refund', 'count': 96, 'amount': 7400},
          {'type': 'debit', 'source': 'game_entry', 'count': 8742, 'amount': 458800},
          {'type': 'debit', 'source': 'admin', 'count': 14, 'amount': 3200},
        ],
      },
      'platformRevenue': <String, dynamic>{'last30Days': sumRev},
      'coinVolume': <String, dynamic>{'last30Days': sumVol},
    });
  }

  static Map<String, dynamic> _settings() => <String, dynamic>{
        'environment': 'demo',
        'version': '1.0.0',
        'node': 'v20.11.0',
        'timezone': 'Asia/Kolkata',
        'game': <String, dynamic>{
          'turnTimeoutSeconds': 15,
          'reconnectTimeoutSeconds': 30,
          'maxSurrenders': 3,
        },
        'economy': <String, dynamic>{'platformFeePercent': 10, 'signupBonusCoins': 100},
        'admin': <String, dynamic>{
          'jwtExpiresIn': '8h',
          'dashboardCacheSeconds': 15,
          'maxCoinAdjust': 100000,
        },
        'rateLimit': <String, dynamic>{'globalMax': 600, 'adminLoginMax': 5},
        'database': <String, dynamic>{'requireReplicaSet': false, 'maxPoolSize': 50},
      };

  static Map<String, dynamic> _dashboard() {
    final s = _s;
    final now = DateTime.now().toUtc();
    final last7 = s.daily.length >= 7 ? s.daily.sublist(s.daily.length - 7) : s.daily;
    return _ok(<String, dynamic>{
      'stats': <String, dynamic>{
        'totalUsers': 12458,
        'usersGrowth': 12.5,
        'activePlayers': 2843,
        'playersGrowth': 18.3,
        'totalGames': 8742,
        'gamesGrowth': 22.4,
        'coinVolume': 182650,
        'coinVolumeGrowth': 25.7,
      },
      'live': <String, dynamic>{'matches': 38, 'playersInMatch': 112},
      'growth': <String, dynamic>{
        'labels': [for (final d in last7) d['label']],
        'total': [11200, 11480, 11760, 11980, 12150, 12310, 12458],
        'active': [2100, 2240, 2330, 2510, 2640, 2760, 2843],
      },
      'modes': <Map<String, dynamic>>[
        {'name': '2 Player', 'percent': 32, 'count': 2795},
        {'name': '4 Player', 'percent': 28, 'count': 2445},
        {'name': 'vs Computer', 'percent': 20, 'count': 1748},
        {'name': 'Team Up (2v2)', 'percent': 12, 'count': 1049},
        {'name': 'Pass N Play', 'percent': 8, 'count': 705},
      ],
      'revenue': <String, dynamic>{
        'labels': [for (final d in last7) d['label']],
        'values': [for (final d in last7) d['coinVolume']],
      },
      'topGames': [
        for (final g in s.games.take(5))
          <String, dynamic>{
            'roomId': '#${g['roomCode']}',
            'mode': g['mode'] == 'twoPlayer' ? '2 Player' : '4 Player',
            'players': '${asList(g['players']).length}/${asList(g['players']).length}',
            'status': g['status'],
            'createdAt': g['createdAt'],
          },
      ],
      'recentUsers': [
        for (final u in s.users.take(5))
          <String, dynamic>{
            'name': u['name'],
            'email': u['email'],
            'joinedOn': u['createdAt'],
            'status': u['status'],
          },
      ],
      'activities': <Map<String, dynamic>>[
        {'title': 'New user registered', 'sub': '${s.users[0]['name']}', 'time': now.subtract(const Duration(minutes: 12)).toIso8601String()},
        {'title': 'Game completed', 'sub': 'Room #${s.games[0]['roomCode']}', 'time': now.subtract(const Duration(minutes: 27)).toIso8601String()},
        {'title': 'User blocked', 'sub': 'Amit Sharma', 'time': now.subtract(const Duration(minutes: 58)).toIso8601String()},
        {'title': 'Coins added', 'sub': 'Ravi Singh (+50)', 'time': now.subtract(const Duration(hours: 1, minutes: 20)).toIso8601String()},
        {'title': 'Support ticket raised', 'sub': '#${s.tickets[0]['ticketNo']}', 'time': now.subtract(const Duration(hours: 2)).toIso8601String()},
      ],
      'onlineUsers': <String, dynamic>{
        'count': 243,
        'list': <Map<String, dynamic>>[
          {'name': 'Rahul Sharma', 'where': 'In Game (4 Player)', 'ago': '2m ago'},
          {'name': 'Priya Singh', 'where': 'In Room (Team Up)', 'ago': '4m ago'},
          {'name': 'Amit Verma', 'where': 'In Game (vs Computer)', 'ago': '6m ago'},
          {'name': 'Neha Patel', 'where': 'In Room (Pass N Play)', 'ago': '8m ago'},
          {'name': 'Sandeep Yadav', 'where': 'Idle', 'ago': '12m ago'},
        ],
      },
      'health': <String, dynamic>{
        'backend': 'Online',
        'database': 'Online',
        'dbPingMs': 18,
        'uptimeSeconds': 345600,
        'memoryMB': 212,
      },
    });
  }

  // -------------------------------------------------------------- seed
  static const List<String> _names = [
    'Rohit Kumar', 'Sneha Singh', 'Aman Gupta', 'Pooja Sharma', 'Vikash Raj',
    'Rahul Sharma', 'Priya Singh', 'Amit Verma', 'Neha Patel', 'Sandeep Yadav',
    'Kunal Sen', 'Ravi Singh', 'Anjali Mehta', 'Deepak Joshi', 'Kavita Nair',
    'Manish Tiwari', 'Ritu Agarwal', 'Sourav Das', 'Meera Iyer', 'Harsh Vardhan',
  ];
  static const List<String> _mon = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _label(DateTime d) => '${_mon[d.month - 1]} ${d.day.toString().padLeft(2, '0')}';

  static _Store _seed() {
    final now = DateTime.now().toUtc();
    String ago(Duration d) => now.subtract(d).toIso8601String();
    final s = _Store();

    // Users
    for (var i = 0; i < 36; i++) {
      final name = i < _names.length ? _names[i] : '${_names[i - _names.length]} Jr.';
      final slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z]+'), '.').replaceAll(RegExp(r'^\.+|\.+$'), '');
      final active = i % 9 != 4;
      final totalGames = 5 + (i * 13) % 240;
      s.users.add(<String, dynamic>{
        'id': 'usr_${1000 + i}',
        'name': name,
        'username': '${slug.replaceAll('.', '_')}_$i',
        'email': '$slug$i@gmail.com',
        'level': 1 + (i * 7) % 25,
        'coins': 150 + (i * 137) % 5200,
        'isActive': active,
        'status': active ? 'Active' : 'Blocked',
        'createdAt': ago(Duration(hours: 6 + i * 19)),
        'statistics': <String, dynamic>{
          'totalGames': totalGames,
          'wins': totalGames * (30 + i % 25) ~/ 100,
        },
      });
    }

    // Games
    const colors = ['red', 'green', 'yellow', 'blue'];
    const gStatus = ['completed', 'completed', 'in_progress', 'abandoned', 'completed'];
    const fees = [0, 10, 20, 50, 100];
    for (var i = 0; i < 45; i++) {
      final two = i % 3 == 0;
      final seats = two ? 2 : 4;
      final status = gStatus[i % 5];
      final fee = fees[i % 5];
      final pool = fee * seats * 90 ~/ 100;
      final players = <Map<String, dynamic>>[
        for (var p = 0; p < seats; p++)
          <String, dynamic>{
            'name': s.users[(i * 3 + p) % s.users.length]['name'],
            'color': colors[p],
            'score': status == 'in_progress' ? (p * 7 + i) % 40 : (p * 11 + i * 3) % 100,
            'outcome': status == 'in_progress'
                ? 'active'
                : (status == 'abandoned' && p == seats - 1 ? 'surrendered' : (p == 0 ? 'won' : 'lost')),
            'prizeEarned': (status == 'completed' && p == 0) ? pool : 0,
            'hasSurrendered': status == 'abandoned' && p == seats - 1,
          },
      ];
      final moves = <Map<String, dynamic>>[
        for (var k = 0; k < 8; k++)
          <String, dynamic>{
            'player': players[k % seats]['name'],
            'dice': (k * 5 + i) % 6 + 1,
            'action': const ['move', 'enter', 'capture', 'move'][k % 4],
            'at': '10:${(15 + k).toString().padLeft(2, '0')}:${((k * 7) % 60).toString().padLeft(2, '0')}',
          },
      ];
      s.games.add(<String, dynamic>{
        'id': 'gm_${5000 + i}',
        'roomCode': '${45872 - i}',
        'mode': two ? 'twoPlayer' : 'fourPlayer',
        'status': status,
        'entryFee': fee,
        'prizePool': pool,
        'winner': status == 'completed' ? players[0]['name'] : null,
        'players': players,
        'moves': moves,
        'createdAt': ago(Duration(minutes: 20 + i * 47)),
      });
    }

    // Support tickets
    const subjects = [
      'Coins not credited after payment', 'Account blocked inquiry', 'App crash during 4-player game',
      'Cannot withdraw winnings', 'Opponent disconnected, lost match', 'Wrong entry fee deducted',
      'Unable to login on new phone', 'Dice result looks unfair', 'Referral bonus missing', 'Change registered email',
    ];
    const cats = ['payment', 'account', 'bug', 'payment', 'game', 'payment', 'account', 'game', 'other', 'account'];
    const prios = ['high', 'normal', 'low', 'normal'];
    const tStatus = ['open', 'in_progress', 'resolved', 'open', 'closed'];
    for (var i = 0; i < 30; i++) {
      final u = s.users[(i * 5) % s.users.length];
      final status = tStatus[i % 5];
      final replies = <Map<String, dynamic>>[
        if (status != 'open')
          <String, dynamic>{
            'authorType': 'admin',
            'message': 'Hi ${u['name']}, we are looking into this and will update you shortly.',
            'createdAt': ago(Duration(hours: 2 + i)),
          },
        if (status == 'resolved' || status == 'closed')
          <String, dynamic>{
            'authorType': 'user',
            'message': 'Thanks, it is working now.',
            'createdAt': ago(Duration(hours: 1 + i)),
          },
      ];
      s.tickets.add(<String, dynamic>{
        'id': 'tk_${2000 + i}',
        'ticketNo': 'TKT-${1024 - i}',
        'subject': subjects[i % subjects.length],
        'category': cats[i % cats.length],
        'priority': prios[i % prios.length],
        'status': status,
        'message': 'Hello team, ${subjects[i % subjects.length].toLowerCase()}. Please help me resolve this as soon as possible.',
        'user': <String, dynamic>{'id': u['id'], 'name': u['name'], 'email': u['email']},
        'replies': replies,
        'replyCount': replies.length,
        'createdAt': ago(Duration(hours: 3 + i * 9)),
      });
    }

    // Transactions
    const sources = ['game_reward', 'game_entry', 'bonus', 'admin', 'refund', 'other'];
    const desc = {
      'game_reward': 'Match prize credited',
      'game_entry': 'Entry fee for match',
      'bonus': 'Signup / daily bonus',
      'admin': 'Admin adjustment',
      'refund': 'Refund for abandoned match',
      'other': 'Miscellaneous',
    };
    for (var i = 0; i < 60; i++) {
      final u = s.users[(i * 7) % s.users.length];
      final source = sources[i % sources.length];
      final debit = source == 'game_entry' || (source == 'admin' && i % 2 == 0);
      final amount = (i * 37) % 480 + 20;
      final before = 500 + (i * 91) % 3000;
      s.transactions.add(<String, dynamic>{
        'id': 'tx_${9000 + i}',
        'user': <String, dynamic>{'id': u['id'], 'name': u['name'], 'email': u['email']},
        'type': debit ? 'debit' : 'credit',
        'amount': amount,
        'source': source,
        'balanceBefore': before,
        'balanceAfter': debit ? math.max(0, before - amount) : before + amount,
        'description': desc[source],
        'createdAt': ago(Duration(minutes: 15 + i * 83)),
      });
    }

    // Daily report (ascending, last 30 days)
    for (var k = 0; k < 30; k++) {
      final day = now.subtract(Duration(days: 29 - k));
      final games = 300 + (k * 41) % 260;
      final vol = games * 38;
      s.daily.add(<String, dynamic>{
        'date': day.toIso8601String().substring(0, 10),
        'label': _label(day),
        'newUsers': 20 + (k * 7) % 35,
        'activePlayers': 120 + (k * 23) % 140 + k * 3,
        'games': games,
        'coinVolume': vol,
        'platformRevenue': vol ~/ 10,
      });
    }

    // Banners (imageUrl null: demo me network image nahi)
    s.banners.addAll(<Map<String, dynamic>>[
      {'id': 'bn_1', 'title': 'IPL Super Tournament', 'subtitle': 'Win up to 10,000 coins', 'type': 'event', 'priority': 90, 'isActive': true, 'linkUrl': null, 'imageUrl': null},
      {'id': 'bn_2', 'title': 'Double Coins Weekend', 'subtitle': 'Every purchase gives 2x coins', 'type': 'banner', 'priority': 70, 'isActive': true, 'linkUrl': null, 'imageUrl': null},
      {'id': 'bn_3', 'title': 'Referral Cashback 50%', 'subtitle': null, 'type': 'banner', 'priority': 40, 'isActive': false, 'linkUrl': null, 'imageUrl': null},
      {'id': 'bn_4', 'title': 'Diwali Mega Contest', 'subtitle': 'Biggest prize pool of the year', 'type': 'event', 'priority': 80, 'isActive': true, 'linkUrl': null, 'imageUrl': null},
    ]);

    // Admins
    s.admins.addAll(<Map<String, dynamic>>[
      Map<String, dynamic>.from(demoAdmin),
      {'id': 'adm_2', 'name': 'Support Manager', 'email': 'support@ludosupreme.com', 'role': 'admin', 'isActive': true, 'lastLogin': ago(const Duration(hours: 5)), 'createdAt': ago(const Duration(days: 40))},
      {'id': 'adm_3', 'name': 'Finance Lead', 'email': 'finance@ludosupreme.com', 'role': 'admin', 'isActive': true, 'lastLogin': ago(const Duration(days: 1)), 'createdAt': ago(const Duration(days: 33))},
      {'id': 'adm_4', 'name': 'Night Moderator', 'email': 'night@ludosupreme.com', 'role': 'admin', 'isActive': false, 'lastLogin': ago(const Duration(days: 12)), 'createdAt': ago(const Duration(days: 20))},
    ]);

    // Audit logs
    const actions = ['admin.login', 'user.block', 'user.unblock', 'user.coins.credit', 'ticket.reply', 'banner.update', 'ticket.status'];
    const targets = ['admin', 'user', 'user', 'user', 'ticket', 'banner', 'ticket'];
    for (var i = 0; i < 40; i++) {
      s.logs.add(<String, dynamic>{
        'id': 'log_$i',
        'createdAt': ago(Duration(minutes: 8 + i * 95)),
        'adminEmail': i % 4 == 0 ? 'support@ludosupreme.com' : demoAdmin['email'],
        'action': actions[i % actions.length],
        'targetType': targets[i % targets.length],
        'targetId': targets[i % targets.length] == 'admin' ? 'adm_demo' : 'id_${3000 + i}',
        'ip': '203.0.113.${10 + i % 40}',
      });
    }
    return s;
  }
}

class _Store {
  final List<Map<String, dynamic>> users = [];
  final List<Map<String, dynamic>> games = [];
  final List<Map<String, dynamic>> tickets = [];
  final List<Map<String, dynamic>> transactions = [];
  final List<Map<String, dynamic>> daily = [];
  final List<Map<String, dynamic>> banners = [];
  final List<Map<String, dynamic>> admins = [];
  final List<Map<String, dynamic>> logs = [];
  final Map<String, Map<String, dynamic>> coinResults = {};
}
