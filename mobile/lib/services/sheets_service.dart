import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_client.dart';

class SheetsService {
  static Future<ApiResult<List<dynamic>>> getSheetWeeks() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiClient.baseUrl}/sheets/weeks'),
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

  static Future<ApiResult<Map<String, dynamic>>> importSheetWeek(Map<String, dynamic> data) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiClient.baseUrl}/sheets/import'),
        headers: await ApiClient.authHeaders(),
        body: jsonEncode(data),
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
