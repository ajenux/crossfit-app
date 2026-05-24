import 'dart:convert';
import 'api_client.dart';

class NotificationService {
  static Future<ApiResult<List<dynamic>>> getNotifications() async {
    final res = await ApiClient.get('${ApiClient.baseUrl}/notifications');
    if (res.statusCode == 200) {
      return ApiResult(
        data: jsonDecode(res.body) as List<dynamic>,
        statusCode: 200,
      );
    }
    return ApiResult(statusCode: res.statusCode);
  }

  static Future<void> markAllRead() async {
    await ApiClient.put('${ApiClient.baseUrl}/notifications/read');
  }
}
