import 'dart:convert';
import 'api_client.dart';

class AthleteService {
  static Future<ApiResult<List<dynamic>>> getAllAthletes() async {
    final res = await ApiClient.get('${ApiClient.baseUrl}/athletes?size=100');
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return ApiResult(data: body['content'] as List<dynamic>, statusCode: 200);
    }
    return ApiResult(statusCode: res.statusCode);
  }

  static Future<ApiResult<List<dynamic>>> getAthletesByCoach(int coachId) async {
    final res = await ApiClient.get('${ApiClient.baseUrl}/athletes?coachId=$coachId&size=100');
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return ApiResult(data: body['content'] as List<dynamic>, statusCode: 200);
    }
    return ApiResult(statusCode: res.statusCode);
  }

  static Future<ApiResult<Map<String, dynamic>>> assignAthleteToCoach(
      int athleteId, String name, String email, int coachId) async {
    final res = await ApiClient.put(
      '${ApiClient.baseUrl}/athletes/$athleteId',
      body: {'name': name, 'email': email, 'coachId': coachId},
    );
    if (res.statusCode == 200) {
      return ApiResult(data: jsonDecode(res.body) as Map<String, dynamic>, statusCode: 200);
    }
    return ApiResult(statusCode: res.statusCode);
  }
}