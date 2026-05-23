import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_client.dart';

class AiService {
  static Future<ApiResult<Map<String, dynamic>>> explainExercise(String exercise) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiClient.baseUrl}/ai/exercise'),
        headers: await ApiClient.authHeaders(),
        body: jsonEncode({'exercise': exercise}),
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