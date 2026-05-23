import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_client.dart';

class WorkoutService {
  static Future<ApiResult<List<dynamic>>> getWorkoutsByCoach(int coachId) async {
    try {
      final res = await http.get(
        Uri.parse('${ApiClient.baseUrl}/workouts?coachId=$coachId&size=100'),
        headers: await ApiClient.authHeaders(),
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return ApiResult(data: body['content'] as List<dynamic>, statusCode: 200);
      }
      return ApiResult(statusCode: res.statusCode);
    } on SocketException {
      return const ApiResult(statusCode: 0);
    }
  }

  static Future<ApiResult<Map<String, dynamic>>> createWorkout(Map<String, dynamic> data) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiClient.baseUrl}/workouts'),
        headers: await ApiClient.authHeaders(),
        body: jsonEncode(data),
      );
      if (res.statusCode == 201) {
        return ApiResult(data: jsonDecode(res.body) as Map<String, dynamic>, statusCode: 201);
      }
      return ApiResult(statusCode: res.statusCode);
    } on SocketException {
      return const ApiResult(statusCode: 0);
    }
  }

  static Future<ApiResult<bool>> deleteWorkout(int id) async {
    try {
      final res = await http.delete(
        Uri.parse('${ApiClient.baseUrl}/workouts/$id'),
        headers: await ApiClient.authHeaders(),
      );
      return ApiResult(data: res.statusCode == 204, statusCode: res.statusCode);
    } on SocketException {
      return const ApiResult(statusCode: 0);
    }
  }
}