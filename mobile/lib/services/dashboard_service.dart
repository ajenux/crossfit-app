import 'dart:convert';
import 'api_client.dart';

class DashboardService {
  static Future<ApiResult<Map<String, dynamic>>> getAthleteDashboard(int athleteId) async {
    final res = await ApiClient.get('${ApiClient.baseUrl}/dashboard/athlete/$athleteId');
    if (res.statusCode == 200) {
      return ApiResult(data: jsonDecode(res.body) as Map<String, dynamic>, statusCode: 200);
    }
    return ApiResult(statusCode: res.statusCode);
  }
}