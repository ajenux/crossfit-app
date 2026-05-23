import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_client.dart';

class AthleteService {
  static Future<ApiResult<List<dynamic>>> getAllAthletes() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiClient.baseUrl}/athletes?size=100'),
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

  static Future<ApiResult<List<dynamic>>> getAthletesByCoach(int coachId) async {
    try {
      final res = await http.get(
        Uri.parse('${ApiClient.baseUrl}/athletes?coachId=$coachId&size=100'),
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

  static Future<ApiResult<Map<String, dynamic>>> assignAthleteToCoach(
      int athleteId, String name, String email, int coachId) async {
    try {
      final res = await http.put(
        Uri.parse('${ApiClient.baseUrl}/athletes/$athleteId'),
        headers: await ApiClient.authHeaders(),
        body: jsonEncode({'name': name, 'email': email, 'coachId': coachId}),
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