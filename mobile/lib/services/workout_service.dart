import 'dart:convert';
import 'api_client.dart';

class WorkoutService {
  static Future<ApiResult<List<dynamic>>> getWorkoutsByCoach(int coachId) async {
    final res = await ApiClient.get('${ApiClient.baseUrl}/workouts?coachId=$coachId&size=100');
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return ApiResult(data: body['content'] as List<dynamic>, statusCode: 200);
    }
    return ApiResult(statusCode: res.statusCode);
  }

  static Future<ApiResult<Map<String, dynamic>>> createWorkout(Map<String, dynamic> data) async {
    final res = await ApiClient.post('${ApiClient.baseUrl}/workouts', body: data);
    if (res.statusCode == 201) {
      return ApiResult(data: jsonDecode(res.body) as Map<String, dynamic>, statusCode: 201);
    }
    return ApiResult(statusCode: res.statusCode);
  }

  static Future<ApiResult<bool>> deleteWorkout(int id) async {
    final res = await ApiClient.delete('${ApiClient.baseUrl}/workouts/$id');
    return ApiResult(data: res.statusCode == 204, statusCode: res.statusCode);
  }
}