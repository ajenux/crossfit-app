import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/screens/auth/login_screen.dart';
import 'package:mobile/services/api_client.dart';

GoRouter _testRouter() => GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/register', builder: (_, __) => const Scaffold(body: Text('Register'))),
        GoRoute(path: '/coach/:id', builder: (_, __) => const Scaffold(body: Text('Coach'))),
        GoRoute(path: '/athlete/:id', builder: (_, __) => const Scaffold(body: Text('Athlete'))),
      ],
    );

Widget _app(GoRouter router) => MaterialApp.router(
      routerConfig: router,
      theme: ThemeData(useMaterial3: true),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    ApiClient.httpClient = http.Client();
  });

  testWidgets('LoginScreen renders all key elements', (tester) async {
    ApiClient.httpClient = MockClient((_) async => http.Response('', 401));

    await tester.pumpWidget(_app(_testRouter()));
    await tester.pumpAndSettle();

    expect(find.text('CrossFit App'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Email'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Password'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
    expect(find.text("Don't have an account? Register"), findsOneWidget);
  });

  testWidgets('LoginScreen shows error on invalid credentials', (tester) async {
    ApiClient.httpClient = MockClient((_) async => http.Response('', 401));

    await tester.pumpWidget(_app(_testRouter()));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Email'), 'user@test.com');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'wrongpassword');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid email or password.'), findsOneWidget);
  });

  testWidgets('LoginScreen shows network error message on connection failure', (tester) async {
    ApiClient.httpClient = MockClient((_) async => throw const SocketException('no connection'));

    await tester.pumpWidget(_app(_testRouter()));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Email'), 'user@test.com');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'somepassword');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pumpAndSettle();

    expect(find.text('Connection error. Make sure the server is running.'), findsOneWidget);
  });

  testWidgets('LoginScreen navigates to coach dashboard on successful coach login', (tester) async {
    ApiClient.httpClient = MockClient((_) async => http.Response(
          '{"token":"tok","refreshToken":"ref","role":"COACH","profileId":3}',
          200,
          headers: {'content-type': 'application/json'},
        ));

    await tester.pumpWidget(_app(_testRouter()));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Email'), 'coach@test.com');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'password123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pumpAndSettle();

    expect(find.text('Coach'), findsOneWidget);
  });
}