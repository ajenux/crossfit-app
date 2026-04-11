import '../models/workout.dart';
import 'api_service.dart';

class WorkoutService {
  static Future<List<Workout>> findAll({int? athleteId, int? coachId}) async {
    String path = '/workouts';
    if (athleteId != null) path += '?athleteId=$athleteId';
    if (coachId != null) path += '?coachId=$coachId';
    final data = await ApiService.get(path) as List;
    return data.map((e) => Workout.fromJson(e)).toList();
  }

  static Future<Workout> findById(int id) async {
    final data = await ApiService.get('/workouts/$id');
    return Workout.fromJson(data);
  }

  static Future<Workout> create({
    required String name,
    required String description,
    required String type,
    required String scheduledDate,
    required int athleteId,
    required int coachId,
  }) async {
    final data = await ApiService.post('/workouts', {
      'name': name,
      'description': description,
      'type': type,
      'scheduledDate': scheduledDate,
      'athleteId': athleteId,
      'coachId': coachId,
    });
    return Workout.fromJson(data);
  }

  static Future<Workout> update({
    required int id,
    required String name,
    required String description,
    required String type,
    required String scheduledDate,
    required int athleteId,
    required int coachId,
  }) async {
    final data = await ApiService.put('/workouts/$id', {
      'name': name,
      'description': description,
      'type': type,
      'scheduledDate': scheduledDate,
      'athleteId': athleteId,
      'coachId': coachId,
    });
    return Workout.fromJson(data);
  }

  static Future<void> delete(int id) async {
    await ApiService.delete('/workouts/$id');
  }
}