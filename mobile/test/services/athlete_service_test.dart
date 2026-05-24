import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/services/api_client.dart';
import 'package:mobile/services/athlete_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'token': 'test-token'});
  });

  tearDown(() {
    ApiClient.httpClient = http.Client();
  });

  group('AthleteService.getAthletesByCoach', () {
    test('returns athletes and isLastPage=false when more pages exist', () async {
      ApiClient.httpClient = MockClient((request) async {
        expect(request.url.queryParameters['coachId'], '1');
        expect(request.url.queryParameters['page'], '0');
        expect(request.url.queryParameters['size'], '20');
        return http.Response(
          '{"content":[{"id":1,"name":"Ana","email":"ana@x.com"}],"last":false,"totalPages":3}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final result = await AthleteService.getAthletesByCoach(1);

      expect(result.isSuccess, true);
      expect(result.data!.length, 1);
      expect(result.data![0]['name'], 'Ana');
      expect(result.isLastPage, false);
    });

    test('returns isLastPage=true on last page', () async {
      ApiClient.httpClient = MockClient((_) async => http.Response(
            '{"content":[{"id":2,"name":"Bob","email":"bob@x.com"}],"last":true,"totalPages":2}',
            200,
            headers: {'content-type': 'application/json'},
          ));

      final result = await AthleteService.getAthletesByCoach(1, page: 1);

      expect(result.isSuccess, true);
      expect(result.isLastPage, true);
    });

    test('passes custom page and size params', () async {
      ApiClient.httpClient = MockClient((request) async {
        expect(request.url.queryParameters['page'], '2');
        expect(request.url.queryParameters['size'], '50');
        return http.Response(
          '{"content":[],"last":true}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      await AthleteService.getAthletesByCoach(1, page: 2, size: 50);
    });

    test('returns error result on non-200 status', () async {
      ApiClient.httpClient = MockClient((_) async => http.Response('Forbidden', 403));

      final result = await AthleteService.getAthletesByCoach(1);

      expect(result.isSuccess, false);
      expect(result.isForbidden, true);
    });
  });

  group('AthleteService.getAllAthletes', () {
    test('returns full list without pagination params', () async {
      ApiClient.httpClient = MockClient((request) async {
        expect(request.url.queryParameters['size'], '100');
        expect(request.url.queryParameters.containsKey('page'), false);
        return http.Response(
          '{"content":[{"id":1,"name":"Ana"},{"id":2,"name":"Bob"}],"last":true}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final result = await AthleteService.getAllAthletes();

      expect(result.isSuccess, true);
      expect(result.data!.length, 2);
    });
  });
}