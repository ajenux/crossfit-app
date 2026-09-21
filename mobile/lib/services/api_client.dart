import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiResult<T> {
  final T? data;
  final int statusCode;
  final bool isLastPage;

  const ApiResult({this.data, required this.statusCode, this.isLastPage = true});

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNetworkError => statusCode == 0;

  String get errorMessage {
    if (isNetworkError) return 'Connection error. Make sure the server is running.';
    if (isUnauthorized) return 'Session expired. Please log in again.';
    if (isForbidden) return 'You don\'t have permission to access this.';
    return 'Something went wrong (error $statusCode). Please try again.';
  }
}

class ApiClient {
  // API_URL is injected at build time via --dart-define=API_URL=https://...
  // Default: localhost for web (no emulator networking), 10.0.2.2 for
  // Android emulator. For iOS simulator use --dart-define=API_URL=http://localhost:8080/api
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: kIsWeb ? 'http://localhost:8080/api' : 'http://10.0.2.2:8080/api',
  );

  // Replaceable in tests via ApiClient.httpClient = MockClient(...)
  static http.Client httpClient = http.Client();

  // ── Token storage ─────────────────────────────────────────────────────────

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('role');
  }

  static Future<int?> getProfileId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('profileId');
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refreshToken');
  }

  static Future<void> saveTokens({
    required String token,
    required String refreshToken,
    required String role,
    int? profileId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('refreshToken', refreshToken);
    await prefs.setString('role', role);
    if (profileId != null) await prefs.setInt('profileId', profileId);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('refreshToken');
    await prefs.remove('role');
    await prefs.remove('profileId');
  }

  static Future<Map<String, String>> authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── HTTP wrappers with automatic 401 → refresh → retry ───────────────────

  static Future<http.Response> get(String url) async {
    try {
      var res = await httpClient.get(Uri.parse(url), headers: await authHeaders());
      if (res.statusCode == 401) {
        if (await _tryRefresh()) {
          res = await httpClient.get(Uri.parse(url), headers: await authHeaders());
        }
      }
      return res;
    } on SocketException {
      return http.Response('', 0);
    }
  }

  static Future<http.Response> post(String url, {Object? body}) async {
    try {
      var res = await httpClient.post(Uri.parse(url),
          headers: await authHeaders(), body: body != null ? jsonEncode(body) : null);
      if (res.statusCode == 401) {
        if (await _tryRefresh()) {
          res = await httpClient.post(Uri.parse(url),
              headers: await authHeaders(), body: body != null ? jsonEncode(body) : null);
        }
      }
      return res;
    } on SocketException {
      return http.Response('', 0);
    }
  }

  static Future<http.Response> put(String url, {Object? body}) async {
    try {
      var res = await httpClient.put(Uri.parse(url),
          headers: await authHeaders(), body: body != null ? jsonEncode(body) : null);
      if (res.statusCode == 401) {
        if (await _tryRefresh()) {
          res = await httpClient.put(Uri.parse(url),
              headers: await authHeaders(), body: body != null ? jsonEncode(body) : null);
        }
      }
      return res;
    } on SocketException {
      return http.Response('', 0);
    }
  }

  static Future<http.Response> delete(String url) async {
    try {
      var res = await httpClient.delete(Uri.parse(url), headers: await authHeaders());
      if (res.statusCode == 401) {
        if (await _tryRefresh()) {
          res = await httpClient.delete(Uri.parse(url), headers: await authHeaders());
        }
      }
      return res;
    } on SocketException {
      return http.Response('', 0);
    }
  }

  // Calls /api/auth/refresh. Returns true if a new access token was saved.
  static Future<bool> _tryRefresh() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null) return false;
    try {
      final res = await httpClient.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        await saveTokens(
          token: body['token'],
          refreshToken: body['refreshToken'],
          role: body['role'],
          profileId: body['profileId'],
        );
        return true;
      }
    } catch (_) {}
    return false;
  }
}