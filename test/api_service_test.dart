import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ludo_supreme_admin/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiService.init();
    ApiService.token = null;
    ApiService.currentAdmin = null;
    ApiService.demo = false;
  });

  group('ApiService Configuration & State Tests', () {
    test('Default base URL is properly set', () {
      expect(ApiService.baseUrl, equals('http://192.168.1.20:4000/api'));
      expect(ApiService.token, isNull);
      expect(ApiService.currentAdmin, isNull);
      expect(ApiService.isSuperAdmin, isFalse);
    });

    test('isSuperAdmin returns true only for superadmin role', () {
      ApiService.currentAdmin = {'role': 'admin'};
      expect(ApiService.isSuperAdmin, isFalse);

      ApiService.currentAdmin = {'role': 'superadmin'};
      expect(ApiService.isSuperAdmin, isTrue);

      ApiService.currentAdmin = {'role': 'SUPERADMIN'};
      expect(ApiService.isSuperAdmin, isTrue);
    });

    test('logout clears credentials and reset state', () async {
      ApiService.token = 'test-token-xyz';
      ApiService.currentAdmin = {'email': 'admin@ludosupreme.com', 'role': 'superadmin'};
      ApiService.demo = true;

      await ApiService.logout();

      expect(ApiService.token, isNull);
      expect(ApiService.currentAdmin, isNull);
      expect(ApiService.demo, isFalse);
    });

    test('ApiException stores message, status code, and requestId', () {
      final ex = ApiException('Resource not found', statusCode: 404, requestId: 'req-1234');
      expect(ex.message, equals('Resource not found'));
      expect(ex.statusCode, equals(404));
      expect(ex.requestId, equals('req-1234'));
      expect(ex.toString(), equals('Resource not found'));
    });
  });
}
