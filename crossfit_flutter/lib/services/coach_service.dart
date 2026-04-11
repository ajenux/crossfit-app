import '../models/coach.dart';
import 'api_service.dart';

class CoachService {
  static Future<List<Coach>> findAll() async {
    final data = await ApiService.get('/coaches') as List;
    return data.map((e) => Coach.fromJson(e)).toList();
  }

  static Future<Coach> findById(int id) async {
    final data = await ApiService.get('/coaches/$id');
    return Coach.fromJson(data);
  }

  static Future<Coach> create(String name, String email) async {
    final data = await ApiService.post('/coaches', {'name': name, 'email': email});
    return Coach.fromJson(data);
  }

  static Future<Coach> update(int id, String name, String email) async {
    final data = await ApiService.put('/coaches/$id', {'name': name, 'email': email});
    return Coach.fromJson(data);
  }

  static Future<void> delete(int id) async {
    await ApiService.delete('/coaches/$id');
  }
}