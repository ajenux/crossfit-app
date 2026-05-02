import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/athlete/athlete_dashboard_screen.dart';
import 'screens/athlete/exercise_assistant_screen.dart';
import 'screens/coach/coach_dashboard_screen.dart';

// Injected at build time: flutter build web --dart-define=DEMO_MODE=true
const bool kDemoMode = bool.fromEnvironment('DEMO_MODE', defaultValue: false);

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
      builder: kDemoMode
          ? (context, child) => _DemoBanner(child: child!)
          : null,
    );
  }
}

/// Shown on all screens when the app is running in demo mode.
/// Reminds stakeholders that data is not real.
class _DemoBanner extends StatelessWidget {
  final Widget child;
  const _DemoBanner({required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.deepOrange,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.science_outlined, color: Colors.white, size: 14),
                  SizedBox(width: 6),
                  Text(
                    'Demo environment — data is not real',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
