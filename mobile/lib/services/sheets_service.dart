import 'dart:convert';
import 'api_client.dart';

class SheetsService {
  static Future<ApiResult<List<dynamic>>> getSheetTabs() async {
    final res = await ApiClient.get('${ApiClient.baseUrl}/sheets/tabs');
    if (res.statusCode == 200) {
      return ApiResult(data: jsonDecode(res.body) as List<dynamic>, statusCode: 200);
    }
    return ApiResult(statusCode: res.statusCode);
  }

  static Future<ApiResult<List<dynamic>>> getSheetWeeks(String sheetName) async {
    final encoded = Uri.encodeComponent(sheetName);
    final res = await ApiClient.get('${ApiClient.baseUrl}/sheets/weeks?sheet=$encoded');
    if (res.statusCode == 200) {
      return ApiResult(data: jsonDecode(res.body) as List<dynamic>, statusCode: 200);
    }
    return ApiResult(statusCode: res.statusCode);
  }

  static Future<ApiResult<Map<String, dynamic>>> importSheetWeek(Map<String, dynamic> data) async {
    final res = await ApiClient.post('${ApiClient.baseUrl}/sheets/import', body: data);
    if (res.statusCode == 200) {
      return ApiResult(data: jsonDecode(res.body) as Map<String, dynamic>, statusCode: 200);
    }
    return ApiResult(statusCode: res.statusCode);
  }
}