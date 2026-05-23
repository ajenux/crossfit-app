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

class ApiClient {
  // API_URL is injected at build time via --dart-define=API_URL=https://...
  // Defaults to Android emulator address for local development.
  // For iOS simulator use: --dart-define=API_URL=http://localhost:8080/api
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:8080/api',
  );

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

  static Future<Map<String, String>> authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

}