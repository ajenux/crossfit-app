import 'dart:convert';
import 'api_client.dart';

class ImportConfigService {
  static Future<ApiResult<Map<String, dynamic>>> getConfig(int coachId) async {
    final res = await ApiClient.get('${ApiClient.baseUrl}/import-config/$coachId');
    if (res.statusCode == 200) {
      return ApiResult(data: jsonDecode(res.body) as Map<String, dynamic>, statusCode: 200);
    }
    return ApiResult(statusCode: res.statusCode);
  }

  static Future<ApiResult<Map<String, dynamic>>> saveConfig(Map<String, dynamic> data) async {
    final res = await ApiClient.put('${ApiClient.baseUrl}/import-config', body: data);
    if (res.statusCode == 200) {
      return ApiResult(data: jsonDecode(res.body) as Map<String, dynamic>, statusCode: 200);
    }
    return ApiResult(statusCode: res.statusCode);
  }
}