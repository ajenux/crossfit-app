import 'dart:convert';
import 'dart:io';
import 'api_client.dart';

class AuthService {
  static Future<ApiResult<Map<String, dynamic>>> login(String email, String password) async {
    try {
      final res = await ApiClient.httpClient.post(
        Uri.parse('${ApiClient.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        await _saveSession(body);
        return ApiResult(data: body, statusCode: 200);
      }
      // On failure, try to surface the backend's ProblemDetail 'detail' message
      // (e.g. "Please verify your email before logging in") instead of a generic one.
      return ApiResult(data: _tryParseJsonBody(res.body), statusCode: res.statusCode);
    } on SocketException {
      return const ApiResult(statusCode: 0);
    }
  }

  static Future<ApiResult<bool>> register(
      String name, String email, String password, String role) async {
    try {
      final res = await ApiClient.httpClient.post(
        Uri.parse('${ApiClient.baseUrl}/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'email': email, 'password': password, 'role': role}),
      );
      return ApiResult(data: res.statusCode == 200, statusCode: res.statusCode);
    } on SocketException {
      return const ApiResult(statusCode: 0);
    }
  }

  static Future<ApiResult<bool>> verifyEmail(String token) async {
    try {
      final res = await ApiClient.httpClient.post(
        Uri.parse('${ApiClient.baseUrl}/auth/verify-email'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': token}),
      );
      return ApiResult(data: res.statusCode == 200, statusCode: res.statusCode);
    } on SocketException {
      return const ApiResult(statusCode: 0);
    }
  }

  static Future<ApiResult<bool>> resendVerification(String email) async {
    try {
      final res = await ApiClient.httpClient.post(
        Uri.parse('${ApiClient.baseUrl}/auth/resend-verification'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      return ApiResult(data: res.statusCode == 200, statusCode: res.statusCode);
    } on SocketException {
      return const ApiResult(statusCode: 0);
    }
  }

  static Map<String, dynamic>? _tryParseJsonBody(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static Future<ApiResult<bool>> forgotPassword(String email) async {
    try {
      final res = await ApiClient.httpClient.post(
        Uri.parse('${ApiClient.baseUrl}/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      return ApiResult(data: res.statusCode == 200, statusCode: res.statusCode);
    } on SocketException {
      return const ApiResult(statusCode: 0);
    }
  }

  static Future<ApiResult<bool>> resetPassword(String token, String newPassword) async {
    try {
      final res = await ApiClient.httpClient.post(
        Uri.parse('${ApiClient.baseUrl}/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': token, 'newPassword': newPassword}),
      );
      return ApiResult(data: res.statusCode == 200, statusCode: res.statusCode);
    } on SocketException {
      return const ApiResult(statusCode: 0);
    }
  }

  static Future<void> logout() async {
    final refreshToken = await ApiClient.getRefreshToken();
    if (refreshToken != null) {
      try {
        await ApiClient.httpClient.post(
          Uri.parse('${ApiClient.baseUrl}/auth/logout'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': refreshToken}),
        );
      } catch (_) {}
    }
    await ApiClient.clearToken();
  }

  static Future<void> _saveSession(Map<String, dynamic> body) async {
    await ApiClient.saveTokens(
      token: body['token'],
      refreshToken: body['refreshToken'] ?? '',
      role: body['role'],
      profileId: body['profileId'],
    );
  }
}