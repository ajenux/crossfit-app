import 'dart:convert';
import 'api_client.dart';

class AvailabilityService {
  static Future<ApiResult<List<dynamic>>> getCoachAvailability(int coachId) async {
    final res = await ApiClient.get('${ApiClient.baseUrl}/availability/coach/$coachId');
    if (res.statusCode == 200) {
      return ApiResult(data: jsonDecode(res.body) as List<dynamic>, statusCode: 200);
    }
    return ApiResult(statusCode: res.statusCode);
  }

  static Future<ApiResult<bool>> addAvailability(Map<String, dynamic> data) async {
    final res = await ApiClient.post('${ApiClient.baseUrl}/availability', body: data);
    return ApiResult(data: res.statusCode == 201, statusCode: res.statusCode);
  }

  static Future<ApiResult<bool>> deleteAvailability(int id) async {
    final res = await ApiClient.delete('${ApiClient.baseUrl}/availability/$id');
    return ApiResult(data: res.statusCode == 204, statusCode: res.statusCode);
  }
}