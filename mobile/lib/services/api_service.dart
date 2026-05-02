import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiResult<T> {
  final T? data;
  final int statusCode;

  const ApiResult({this.data, required this.statusCode});

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

class ApiService {
  static const String baseUrl = 'http://10.0.2.2:8080/api'; // Android emulator
  // Use 'http://localhost:8080/api' for iOS simulator

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

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('role');
    await prefs.remove('profileId');
  }

  static Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Auth
  static Future<ApiResult<Map<String, dynamic>>> login(String email, String password) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', body['token']);
        await prefs.setString('role', body['role']);
        if (body['profileId'] != null) {
          await prefs.setInt('profileId', body['profileId']);
        }
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
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'email': email, 'password': password, 'role': role}),
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', body['token']);
        await prefs.setString('role', body['role']);
        if (body['profileId'] != null) {
          await prefs.setInt('profileId', body['profileId']);
        }
        return ApiResult(data: body, statusCode: 200);
      }
      return ApiResult(statusCode: res.statusCode);
    } on SocketException {
      return const ApiResult(statusCode: 0);
    }
  }

  // Athlete dashboard
  static Future<ApiResult<Map<String, dynamic>>> getAthleteDashboard(int athleteId) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/dashboard/athlete/$athleteId'),
        headers: await _authHeaders(),
      );
      if (res.statusCode == 200) {
        return ApiResult(data: jsonDecode(res.body) as Map<String, dynamic>, statusCode: 200);
      }
      return ApiResult(statusCode: res.statusCode);
    } on SocketException {
      return const ApiResult(statusCode: 0);
    }
  }

  // Coach availability
  static Future<ApiResult<List<dynamic>>> getCoachAvailability(int coachId) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/availability/coach/$coachId'),
        headers: await _authHeaders(),
      );
      if (res.statusCode == 200) {
        return ApiResult(data: jsonDecode(res.body) as List<dynamic>, statusCode: 200);
      }
      return ApiResult(statusCode: res.statusCode);
    } on SocketException {
      return const ApiResult(statusCode: 0);
    }
  }

  static Future<ApiResult<bool>> addAvailability(Map<String, dynamic> data) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/availability'),
        headers: await _authHeaders(),
        body: jsonEncode(data),
      );
      return ApiResult(data: res.statusCode == 201, statusCode: res.statusCode);
    } on SocketException {
      return const ApiResult(statusCode: 0);
    }
  }

  static Future<ApiResult<bool>> deleteAvailability(int id) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/availability/$id'),
        headers: await _authHeaders(),
      );
      return ApiResult(data: res.statusCode == 204, statusCode: res.statusCode);
    } on SocketException {
      return const ApiResult(statusCode: 0);
    }
  }

  // AI exercise assistant
  static Future<ApiResult<Map<String, dynamic>>> explainExercise(String exercise) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/ai/exercise'),
        headers: await _authHeaders(),
        body: jsonEncode({'exercise': exercise}),
      );
      if (res.statusCode == 200) {
        return ApiResult(data: jsonDecode(res.body) as Map<String, dynamic>, statusCode: 200);
      }
      return ApiResult(statusCode: res.statusCode);
    } on SocketException {
      return const ApiResult(statusCode: 0);
    }
  }
}
