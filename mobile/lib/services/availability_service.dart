import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_client.dart';

class AvailabilityService {
  static Future<ApiResult<List<dynamic>>> getCoachAvailability(int coachId) async {
    try {
      final res = await http.get(
        Uri.parse('${ApiClient.baseUrl}/availability/coach/$coachId'),
        headers: await ApiClient.authHeaders(),
      );
      if (res.statusCode == 200) {
        return ApiResult(data: jsonDecode(res.body) as List<dynamic>, statusCode: 200);
      }
      return ApiResult(statusCode: res.statusCode);
    } on SocketException {
      return const ApiResult(statusCode: 0);
    }
  }

  static Future<ApiResult<bool>> addAvailability(Map<String, dynamic> data) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiClient.baseUrl}/availability'),
        headers: await ApiClient.authHeaders(),
        body: jsonEncode(data),
      );
      return ApiResult(data: res.statusCode == 201, statusCode: res.statusCode);
    } on SocketException {
      return const ApiResult(statusCode: 0);
    }
  }

  static Future<ApiResult<bool>> deleteAvailability(int id) async {
    try {
      final res = await http.delete(
        Uri.parse('${ApiClient.baseUrl}/availability/$id'),
        headers: await ApiClient.authHeaders(),
      );
      return ApiResult(data: res.statusCode == 204, statusCode: res.statusCode);
    } on SocketException {
      return const ApiResult(statusCode: 0);
    }
  }
}