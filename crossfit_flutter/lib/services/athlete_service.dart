import '../models/athlete.dart';
import 'api_service.dart';

class AthleteService {
  static Future<List<Athlete>> findAll({int? coachId}) async {
    final path = coachId != null ? '/athletes?coachId=$coachId' : '/athletes';
    final data = await ApiService.get(path) as List;
    return data.map((e) => Athlete.fromJson(e)).toList();
  }

  static Future<Athlete> findById(int id) async {
    final data = await ApiService.get('/athletes/$id');
    return Athlete.fromJson(data);
  }

  static Future<Athlete> create(String name, String email, int coachId) async {
    final data = await ApiService.post('/athletes', {
      'name': name,
      'email': email,
      'coachId': coachId,
    });
    return Athlete.fromJson(data);
  }

  static Future<Athlete> update(int id, String name, String email, int coachId) async {
    final data = await ApiService.put('/athletes/$id', {
      'name': name,
      'email': email,
      'coachId': coachId,
    });
    return Athlete.fromJson(data);
  }

  static Future<void> delete(int id) async {
    await ApiService.delete('/athletes/$id');
  }
}