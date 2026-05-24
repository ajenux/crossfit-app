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
}