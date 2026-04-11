import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_response.dart';
import 'api_service.dart';

class AuthService {
  static Future<AuthResponse> login(String username, String password) async {
    final data = await ApiService.post('/auth/login', {
      'username': username,
      'password': password,
    });
    final response = AuthResponse.fromJson(data);
    await _saveToken(response.token);
    return response;
  }

  static Future<AuthResponse> register(
      String username, String password, String role) async {
    final data = await ApiService.post('/auth/register', {
      'username': username,
      'password': password,
      'role': role,
    });
    final response = AuthResponse.fromJson(data);
    await _saveToken(response.token);
    return response;
  }

  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token') != null;
  }
}