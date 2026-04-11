import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _role = 'ATHLETE';
  bool _loading = false;
  String? _error;

  Future<void> _register() async {
    setState(() { _loading = true; _error = null; });
    final token = await ApiService.register(
      _emailController.text.trim(),
      _passwordController.text.trim(),
      _role,
    );
    setState(() => _loading = false);
    if (token != null && mounted) {
      context.go(_role == 'COACH' ? '/coach/1' : '/athlete/1');
    } else {
      setState(() => _error = 'Registration failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
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
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _role,
                decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'ATHLETE', child: Text('Athlete')),
                  DropdownMenuItem(value: 'COACH', child: Text('Coach')),
                ],
                onChanged: (v) => setState(() => _role = v!),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _register,
                  child: _loading ? const CircularProgressIndicator() : const Text('Register'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
