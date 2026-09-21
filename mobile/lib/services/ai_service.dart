import 'dart:convert';
import 'api_client.dart';

class AiService {
  static Future<ApiResult<Map<String, dynamic>>> explainExercise(String exercise) async {
    final res = await ApiClient.post('${ApiClient.baseUrl}/ai/exercise', body: {'exercise': exercise});
    if (res.statusCode == 200) {
      return ApiResult(data: jsonDecode(res.body) as Map<String, dynamic>, statusCode: 200);
    }
    return ApiResult(statusCode: res.statusCode);
  }

  static Future<ApiResult<Map<String, dynamic>>> generateWorkout(String name, String type) async {
    final res = await ApiClient.post('${ApiClient.baseUrl}/ai/generate-workout', body: {'name': name, 'type': type});
    if (res.statusCode == 200) {
      return ApiResult(data: jsonDecode(res.body) as Map<String, dynamic>, statusCode: 200);
    }
    return ApiResult(statusCode: res.statusCode);
  }
}