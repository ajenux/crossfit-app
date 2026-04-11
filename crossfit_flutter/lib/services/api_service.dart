import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:8080/api';

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  static Future<Map<String, String>> _authHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<dynamic> get(String path) async {
    final headers = await _authHeaders();
    final response = await http.get(Uri.parse('$baseUrl$path'), headers: headers);
    _checkStatus(response);
    return jsonDecode(response.body);
  }

  static Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: headers,
      body: jsonEncode(body),
    );
    _checkStatus(response);
    return jsonDecode(response.body);
  }

  static Future<dynamic> put(String path, Map<String, dynamic> body) async {
    final headers = await _authHeaders();
    final response = await http.put(
      Uri.parse('$baseUrl$path'),
      headers: headers,
      body: jsonEncode(body),
    );
    _checkStatus(response);
    return jsonDecode(response.body);
  }

  static Future<void> delete(String path) async {
    final headers = await _authHeaders();
    final response = await http.delete(Uri.parse('$baseUrl$path'), headers: headers);
    _checkStatus(response);
  }

  static void _checkStatus(http.Response response) {
    if (response.statusCode >= 400) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }
}