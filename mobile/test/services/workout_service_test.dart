import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/services/api_client.dart';
import 'package:mobile/services/workout_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'token': 'test-token'});
  });

  tearDown(() {
    ApiClient.httpClient = http.Client();
  });

  group('WorkoutService.getWorkoutsByCoach', () {
    test('returns workouts with isLastPage from backend', () async {
      ApiClient.httpClient = MockClient((_) async => http.Response(
            '{"content":[{"id":1,"name":"Fran","type":"FOR_TIME","scheduledDate":"2026-05-23","athleteName":"Ana"}],"last":true}',
            200,
            headers: {'content-type': 'application/json'},
          ));

      final result = await WorkoutService.getWorkoutsByCoach(1);

      expect(result.isSuccess, true);
      expect(result.data!.length, 1);
      expect(result.data![0]['name'], 'Fran');
      expect(result.isLastPage, true);
    });

    test('returns isLastPage=false when more pages remain', () async {
      ApiClient.httpClient = MockClient((_) async => http.Response(
            '{"content":[{"id":1,"name":"Murph","type":"FOR_TIME","scheduledDate":"2026-05-23","athleteName":"Ana"}],"last":false}',
            200,
            headers: {'content-type': 'application/json'},
          ));

      final result = await WorkoutService.getWorkoutsByCoach(1, page: 0);

      expect(result.isLastPage, false);
    });

    test('returns error on non-200 status', () async {
      ApiClient.httpClient = MockClient((_) async => http.Response('', 403));

      final result = await WorkoutService.getWorkoutsByCoach(1);

      expect(result.isSuccess, false);
    });
  });

  group('WorkoutService.createWorkout', () {
    test('returns workout data on 201', () async {
      ApiClient.httpClient = MockClient((_) async => http.Response(
            '{"id":5,"name":"Murph","type":"FOR_TIME"}',
            201,
            headers: {'content-type': 'application/json'},
          ));

      final result = await WorkoutService.createWorkout({
        'name': 'Murph',
        'type': 'FOR_TIME',
        'athleteId': 1,
        'coachId': 2,
        'scheduledDate': '2026-05-23',
      });

      expect(result.isSuccess, true);
      expect(result.data!['id'], 5);
      expect(result.data!['name'], 'Murph');
    });

    test('returns error when creation fails', () async {
      ApiClient.httpClient = MockClient((_) async => http.Response('Bad Request', 400));

      final result = await WorkoutService.createWorkout({'name': ''});

      expect(result.isSuccess, false);
    });
  });

  group('WorkoutService.deleteWorkout', () {
    test('returns true on 204', () async {
      ApiClient.httpClient = MockClient((_) async => http.Response('', 204));

      final result = await WorkoutService.deleteWorkout(1);

      expect(result.isSuccess, true);
      expect(result.data, true);
    });

    test('returns false on error', () async {
      ApiClient.httpClient = MockClient((_) async => http.Response('', 404));

      final result = await WorkoutService.deleteWorkout(999);

      expect(result.isSuccess, false);
      expect(result.data, false);
    });
  });
}