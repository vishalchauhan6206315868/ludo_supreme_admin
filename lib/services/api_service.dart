import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/safe.dart';
import 'api_exception.dart';
import 'demo_data.dart';

export 'api_exception.dart';

class ApiService {
  /// Default URL. Build time par badal sakte hain:
  ///   flutter run --dart-define=API_BASE_URL=https://yourdomain.com/api
  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.20:4000/api',
  );
  static String baseUrl = defaultBaseUrl;
  static String? token;
  static Map<String, dynamic>? currentAdmin;
  static bool demo = false;
  static VoidCallback? onUnauthorized;

  // Ek hi baar logout redirect ho (parallel 401 par multiple push nahi).
  static bool _unauthorizedFired = false;

  static const Duration _getTimeout = Duration(seconds: 15);
  static const Duration _writeTimeout = Duration(seconds: 20);

  static bool get isSuperAdmin =>
      (currentAdmin?['role'] ?? '').toString().toLowerCase() == 'superadmin';

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    baseUrl = prefs.getString('baseUrl') ?? defaultBaseUrl;
    token = prefs.getString('token');
    _unauthorizedFired = false;
    final adminStr = prefs.getString('currentAdmin');
    if (adminStr != null) {
      try {
        currentAdmin = jsonDecode(adminStr) as Map<String, dynamic>?;
      } catch (_) {}
    }
  }

  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('baseUrl', baseUrl);
    if (token != null) {
      await prefs.setString('token', token!);
    } else {
      await prefs.remove('token');
    }
    if (currentAdmin != null) {
      await prefs.setString('currentAdmin', jsonEncode(currentAdmin));
    } else {
      await prefs.remove('currentAdmin');
    }
  }

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  static Uri _buildUri(String path, [Map<String, dynamic>? query]) {
    final cleanBase = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    var cleanPath = path.startsWith('/') ? path : '/$path';

    // Path me embedded "?a=b" ho to usse query map me merge karo.
    final params = <String, String>{};
    final qi = cleanPath.indexOf('?');
    if (qi >= 0) {
      try {
        params.addAll(Uri.splitQueryString(cleanPath.substring(qi + 1)));
      } catch (_) {}
      cleanPath = cleanPath.substring(0, qi);
    }
    query?.forEach((key, value) {
      if (value != null && '$value'.trim().isNotEmpty) {
        params[key] = '$value';
      }
    });

    final base = Uri.parse('$cleanBase$cleanPath');
    return params.isEmpty ? base : base.replace(queryParameters: params);
  }

  static void _handleUnauthorized() {
    token = null;
    currentAdmin = null;
    _save();
    if (_unauthorizedFired) return;
    _unauthorizedFired = true;
    onUnauthorized?.call();
  }

  static dynamic _handleResponse(http.Response r, {bool isAuthRequest = false}) {
    final text = r.body.trim();
    if (text.isEmpty) {
      if (r.statusCode == 401 && !isAuthRequest) _handleUnauthorized();
      if (r.statusCode >= 400) {
        throw ApiException('Server returned error (${r.statusCode})', statusCode: r.statusCode);
      }
      return {'success': true};
    }

    dynamic body;
    try {
      body = jsonDecode(text);
    } catch (_) {
      if (r.statusCode == 401 && !isAuthRequest) _handleUnauthorized();
      if (r.statusCode >= 400) {
        throw ApiException('Server error (${r.statusCode})', statusCode: r.statusCode);
      }
      return r.body;
    }

    if (r.statusCode == 401) {
      // Login endpoint ka 401 = galat password; session expiry nahi.
      final fallback = isAuthRequest ? 'Invalid email or password' : 'Session expired. Please login again.';
      final msg = body is Map ? '${body['message'] ?? fallback}' : 'Unauthorized';
      if (!isAuthRequest) _handleUnauthorized();
      throw ApiException(msg, statusCode: 401);
    }

    if (r.statusCode >= 400) {
      var msg = 'Request failed (${r.statusCode})';
      String? reqId;
      if (body is Map) {
        final m = body['message'] ?? body['error'];
        if (m != null) msg = '$m';
        reqId = body['requestId']?.toString();
      }
      throw ApiException(msg, statusCode: r.statusCode, requestId: reqId);
    }

    return body;
  }

  static Future<T> _safeCall<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('Connection timed out. Server is taking too long to respond.', statusCode: 408);
    } on FormatException {
      throw ApiException('Invalid server URL: $baseUrl', statusCode: 400);
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('timeout')) {
        throw ApiException('Connection timed out. Server is taking too long to respond.', statusCode: 408);
      }
      if (errStr.contains('connection refused') ||
          errStr.contains('failed host lookup') ||
          errStr.contains('socketexception') ||
          errStr.contains('clientexception') ||
          errStr.contains('failed to fetch')) {
        final webHint = kIsWeb ? ' (Web: backend CORS me is panel ka origin allow hona chahiye.)' : '';
        throw ApiException(
          'Unable to connect to server at $baseUrl. Verify the backend is running.$webHint',
          statusCode: 503,
        );
      }
      throw ApiException(e.toString());
    }
  }

  // ---------------------------------------------------------------- demo
  static Future<dynamic> _demoRequest(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? body,
  }) async {
    // Thoda latency simulate karo taaki loading states bhi dikhein.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return DemoData.handle(method, path, query: query, body: body);
  }

  /// Demo mode: koi network call nahi, saara data in-memory.
  static void enterDemo() {
    demo = true;
    token = null;
    _unauthorizedFired = false;
    DemoData.reset();
    currentAdmin = Map<String, dynamic>.from(DemoData.demoAdmin);
  }

  // ------------------------------------------------------------ requests
  static Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? body,
  }) {
    return _safeCall(() async {
      final uri = _buildUri(path, query);
      final isAuth = path.endsWith('/admin/login');
      final http.Response r;
      if (method == 'POST') {
        r = await http.post(uri, headers: _headers, body: jsonEncode(body ?? {})).timeout(_writeTimeout);
      } else if (method == 'PATCH') {
        r = await http.patch(uri, headers: _headers, body: jsonEncode(body ?? {})).timeout(_writeTimeout);
      } else if (method == 'DELETE') {
        r = await http.delete(uri, headers: _headers).timeout(_writeTimeout);
      } else {
        r = await http.get(uri, headers: _headers).timeout(_getTimeout);
      }
      return _handleResponse(r, isAuthRequest: isAuth);
    });
  }

  static Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (demo) return _demoRequest('GET', path, query: query);
    try {
      return await _request('GET', path, query: query);
    } on ApiException catch (e) {
      // GET idempotent hai: network blip / timeout par ek baar auto-retry.
      if (e.statusCode == 503 || e.statusCode == 408) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        return _request('GET', path, query: query);
      }
      rethrow;
    }
  }

  static Future<dynamic> post(String path, Map<String, dynamic> body) async {
    if (demo) return _demoRequest('POST', path, body: body);
    return _request('POST', path, body: body);
  }

  static Future<dynamic> patch(String path, Map<String, dynamic> body) async {
    if (demo) return _demoRequest('PATCH', path, body: body);
    return _request('PATCH', path, body: body);
  }

  static Future<dynamic> delete(String path) async {
    if (demo) return _demoRequest('DELETE', path);
    return _request('DELETE', path);
  }

  // ---------------------------------------------------------------- auth
  static Future<void> login(String url, String email, String password) async {
    final cleaned = url.trim().replaceAll(RegExp(r'/+$'), '');
    final u = Uri.tryParse(cleaned);
    if (u == null || !(u.scheme == 'http' || u.scheme == 'https') || u.host.isEmpty) {
      throw ApiException('Enter a valid API URL starting with http:// or https://', statusCode: 400);
    }
    baseUrl = cleaned;
    demo = false;
    _unauthorizedFired = false;

    final res = await post('/admin/login', {
      'email': email.trim(),
      'password': password,
    });

    final root = asMap(res);
    final data = asMap(root['data']);
    if (data.isNotEmpty && data['token'] != null) {
      token = data['token'].toString();
      final adm = asMap(data['admin']);
      if (adm.isNotEmpty) currentAdmin = adm;
    } else if (root['token'] != null) {
      token = root['token'].toString();
    }

    if (token == null || token!.isEmpty) {
      token = null;
      throw ApiException('Authentication token not received');
    }
    await _save();
  }

  static Future<void> fetchProfile() async {
    if (demo) {
      currentAdmin ??= Map<String, dynamic>.from(DemoData.demoAdmin);
      return;
    }
    if (token == null) return;
    try {
      final res = await get('/admin/me');
      final admin = asMap(asMap(asMap(res)['data'])['admin']);
      if (admin.isNotEmpty) {
        currentAdmin = admin;
        await _save();
      }
    } catch (_) {}
  }

  static Future<void> changePassword(String currentPassword, String newPassword) async {
    final res = await post('/admin/change-password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
    final t = asMap(asMap(res)['data'])['token'];
    if (t != null && !demo) {
      token = t.toString();
      await _save();
    }
  }

  static Future<void> logoutAll() async {
    if (demo) {
      await logout();
      return;
    }
    try {
      if (token != null) {
        await post('/admin/logout-all', {});
      }
    } finally {
      token = null;
      currentAdmin = null;
      demo = false;
      await _save();
    }
  }

  static Future<void> logout() async {
    final wasDemo = demo;
    token = null;
    currentAdmin = null;
    demo = false;
    DemoData.reset();
    // Demo se exit karne par asli saved session ko mat chhedo.
    if (!wasDemo) await _save();
  }
}
