import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://10.0.2.2:8080/api'; // Android emulator
  // Use 'http://localhost:8080/api' for iOS simulator

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
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
  static Future<Map<String, dynamic>?> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', body['token']);
      await prefs.setString('role', body['role']);
      if (body['profileId'] != null) {
        await prefs.setInt('profileId', body['profileId']);
      }
      return body;
    }
    return null;
  }

  static Future<Map<String, dynamic>?> register(String name, String email, String password, String role) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'email': email, 'password': password, 'role': role}),
    );
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', body['token']);
      await prefs.setString('role', body['role']);
      if (body['profileId'] != null) {
        await prefs.setInt('profileId', body['profileId']);
      }
      return body;
    }
    return null;
  }

  // Athlete dashboard
  static Future<Map<String, dynamic>?> getAthleteDashboard(int athleteId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/dashboard/athlete/$athleteId'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return null;
  }

  // Coach availability
  static Future<List<dynamic>> getCoachAvailability(int coachId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/availability/coach/$coachId'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  static Future<bool> addAvailability(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$baseUrl/availability'),
      headers: await _authHeaders(),
      body: jsonEncode(data),
    );
    return res.statusCode == 201;
  }

  static Future<bool> deleteAvailability(int id) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/availability/$id'),
      headers: await _authHeaders(),
    );
    return res.statusCode == 204;
  }

  // AI exercise assistant
  static Future<Map<String, dynamic>?> explainExercise(String exercise) async {
    final res = await http.post(
      Uri.parse('$baseUrl/ai/exercise'),
      headers: await _authHeaders(),
      body: jsonEncode({'exercise': exercise}),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return null;
  }
}
