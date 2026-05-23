import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_client.dart';

class DashboardService {
  static Future<ApiResult<Map<String, dynamic>>> getAthleteDashboard(int athleteId) async {
    try {
      final res = await http.get(
        Uri.parse('${ApiClient.baseUrl}/dashboard/athlete/$athleteId'),
        headers: await ApiClient.authHeaders(),
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