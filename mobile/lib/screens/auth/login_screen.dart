import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    final result = await AuthService.login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );
    setState(() => _loading = false);
    if (!mounted) return;
    if (result.isSuccess && result.data != null) {
      final role = result.data!['role'] as String?;
      final profileId = result.data!['profileId'];
      if (role == 'ATHLETE' && profileId != null) {
        context.go('/athlete/$profileId');
      } else if (role == 'COACH' && profileId != null) {
        context.go('/coach/$profileId');
      } else {
        setState(() => _error = 'Profile not found. Contact your administrator.');
      }
    } else if (result.isNetworkError) {
      setState(() => _error = result.errorMessage);
    } else {
      setState(() => _error = 'Invalid email or password.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('CrossFit App', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                obscureText: true,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  child: _loading ? const CircularProgressIndicator() : const Text('Login'),
                ),
              ),
              TextButton(
                onPressed: () => context.go('/register'),
                child: const Text('Don\'t have an account? Register'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
