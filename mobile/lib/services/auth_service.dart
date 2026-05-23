import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

class AuthService {
  static Future<ApiResult<Map<String, dynamic>>> login(String email, String password) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiClient.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        await _saveSession(body);
        return ApiResult(data: body, statusCode: 200);
      }
      return ApiResult(statusCode: res.statusCode);
    } on SocketException {
      return const ApiResult(statusCode: 0);
    }
  }

  static Future<ApiResult<Map<String, dynamic>>> register(
      String name, String email, String password, String role) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiClient.baseUrl}/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'email': email, 'password': password, 'role': role}),
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        await _saveSession(body);
        return ApiResult(data: body, statusCode: 200);
      }
      return ApiResult(statusCode: res.statusCode);
    } on SocketException {
      return const ApiResult(statusCode: 0);
    }
  }

  static Future<void> _saveSession(Map<String, dynamic> body) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', body['token']);
    await prefs.setString('role', body['role']);
    if (body['profileId'] != null) {
      await prefs.setInt('profileId', body['profileId']);
    }
  }
}