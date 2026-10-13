import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_supreme_admin/services/api_service.dart';
import 'package:ludo_supreme_admin/services/demo_data.dart';
import 'package:ludo_supreme_admin/utils/safe.dart';

Map<String, dynamic> data(dynamic res) => asMap(asMap(res)['data']);

void main() {
  setUp(DemoData.reset);

  group('DemoData matches real API shapes', () {
    test('dashboard has every key the dashboard screen reads', () {
      final d = data(DemoData.handle('GET', '/admin/dashboard?refresh=1'));
      for (final k in ['stats', 'live', 'growth', 'modes', 'revenue', 'topGames', 'recentUsers', 'activities', 'onlineUsers', 'health']) {
        expect(d.containsKey(k), isTrue, reason: k);
      }
      final h = asMap(d['health']);
      expect(h['dbPingMs'], isNotNull);
      expect(h['uptimeSeconds'], isNotNull);
      expect(h['memoryMB'], isNotNull);
      expect(asList(asMap(d['growth'])['labels']).length, 7);
    });

    test('users list is paginated, searchable and sortable', () {
      final d = data(DemoData.handle('GET', '/admin/users', query: {'page': 1, 'limit': 10}));
      expect(asList(d['users']).length, 10);
      expect(asMap(d['pagination'])['total'], 36);
      final s = data(DemoData.handle('GET', '/admin/users', query: {'search': 'rohit'}));
      expect(asList(s['users']), isNotEmpty);
      final blocked = data(DemoData.handle('GET', '/admin/users', query: {'status': 'blocked'}));
      expect(asList(blocked['users']).every((u) => asMap(u)['isActive'] == false), isTrue);
    });

    test('every GET endpoint used by the screens resolves', () {
      for (final p in [
        '/admin/me',
        '/admin/games',
        '/admin/support/tickets',
        '/admin/banners',
        '/admin/economy/summary',
        '/admin/reports/daily?days=30',
        '/admin/transactions',
        '/admin/settings',
        '/admin/admins',
        '/admin/audit-logs',
      ]) {
        expect(() => DemoData.handle('GET', p), returnsNormally, reason: p);
      }
      expect(asList(data(DemoData.handle('GET', '/admin/reports/daily?days=30'))['rows']).length, 30);
    });

    test('detail endpoints work and unknown ids give 404', () {
      expect(asMap(data(DemoData.handle('GET', '/admin/users/usr_1000'))['user'])['id'], 'usr_1000');
      expect(asMap(data(DemoData.handle('GET', '/admin/games/gm_5000'))['game'])['moves'], isNotEmpty);
      expect(asMap(data(DemoData.handle('GET', '/admin/support/tickets/tk_2000'))['ticket'])['ticketNo'], isNotNull);
      expect(
        () => DemoData.handle('GET', '/admin/users/nope'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
      );
    });
  });

  group('DemoData write actions stay in memory', () {
    test('block / unblock user', () {
      DemoData.handle('PATCH', '/admin/users/usr_1000/status', body: {'isActive': false});
      var u = asMap(data(DemoData.handle('GET', '/admin/users/usr_1000'))['user']);
      expect(u['isActive'], isFalse);
      expect(u['status'], 'Blocked');
      DemoData.handle('PATCH', '/admin/users/usr_1000/status', body: {'isActive': true});
      u = asMap(data(DemoData.handle('GET', '/admin/users/usr_1000'))['user']);
      expect(u['status'], 'Active');
    });

    test('coin adjust is idempotent for the same key', () {
      final before = asNum(asMap(data(DemoData.handle('GET', '/admin/users/usr_1001'))['user'])['coins']);
      final body = {'type': 'credit', 'amount': 100, 'reason': 'test bonus', 'idempotencyKey': 'k1'};
      final a = data(DemoData.handle('POST', '/admin/users/usr_1001/coins', body: body));
      final b = data(DemoData.handle('POST', '/admin/users/usr_1001/coins', body: body));
      expect(a['balance'], before + 100);
      expect(b['balance'], before + 100); // dobara apply nahi hua
    });

    test('debit more than balance is rejected', () {
      expect(
        () => DemoData.handle('POST', '/admin/users/usr_1001/coins',
            body: {'type': 'debit', 'amount': 99999, 'reason': 'too much', 'idempotencyKey': 'k2'}),
        throwsA(isA<ApiException>()),
      );
    });

    test('banner create / update / delete', () {
      final created = data(DemoData.handle('POST', '/admin/banners', body: {'title': 'New promo', 'priority': 5}));
      final id = asMap(created['banner'])['id'];
      DemoData.handle('PATCH', '/admin/banners/$id', body: {'title': 'Edited'});
      expect(asList(data(DemoData.handle('GET', '/admin/banners'))['banners']).any((b) => asMap(b)['title'] == 'Edited'), isTrue);
      DemoData.handle('DELETE', '/admin/banners/$id');
      expect(asList(data(DemoData.handle('GET', '/admin/banners'))['banners']).any((b) => asMap(b)['id'] == id), isFalse);
    });

    test('admin cannot deactivate own demo account', () {
      expect(
        () => DemoData.handle('PATCH', '/admin/admins/adm_demo/status', body: {'isActive': false}),
        throwsA(isA<ApiException>()),
      );
    });

    test('ticket reply moves open ticket to in_progress', () {
      final open = asList(data(DemoData.handle('GET', '/admin/support/tickets', query: {'status': 'open'}))['tickets']);
      final id = asMap(open.first)['id'];
      DemoData.handle('POST', '/admin/support/tickets/$id/reply', body: {'message': 'Checking now'});
      final t = asMap(data(DemoData.handle('GET', '/admin/support/tickets/$id'))['ticket']);
      expect(t['status'], 'in_progress');
      expect(asList(t['replies']).last['message'], 'Checking now');
    });
  });

  group('ApiService in demo mode never touches the network', () {
    test('get/post/patch/delete are served by DemoData', () async {
      ApiService.enterDemo();
      expect(ApiService.isSuperAdmin, isTrue);
      final r = await ApiService.get('/admin/dashboard', query: {'refresh': '1'});
      expect(data(r)['stats'], isNotNull);
      final p = await ApiService.patch('/admin/users/usr_1002/status', {'isActive': false});
      expect(asMap(p)['success'], isTrue);
      await ApiService.logout();
      expect(ApiService.demo, isFalse);
    });
  });
}
