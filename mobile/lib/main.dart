import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/athlete/athlete_dashboard_screen.dart';
import 'screens/athlete/exercise_assistant_screen.dart';
import 'screens/coach/coach_dashboard_screen.dart';

void main() => runApp(const CrossFitApp());

final _router = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
    GoRoute(
      path: '/athlete/:id',
      builder: (_, state) => AthleteDashboardScreen(
        athleteId: int.parse(state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/coach/:id',
      builder: (_, state) => CoachDashboardScreen(
        coachId: int.parse(state.pathParameters['id']!),
      ),
    ),
    GoRoute(path: '/exercise', builder: (_, __) => const ExerciseAssistantScreen()),
  ],
);

class CrossFitApp extends StatelessWidget {
  const CrossFitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'CrossFit App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}
