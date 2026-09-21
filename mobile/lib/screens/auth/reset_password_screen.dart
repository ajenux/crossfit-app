import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? token;
  const ResetPasswordScreen({super.key, required this.token});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _done = false;

  Future<void> _submit() async {
    final password = _passwordController.text.trim();
    final confirm = _confirmController.text.trim();
    if (widget.token == null || widget.token!.isEmpty) {
      setState(() => _error = 'Missing or invalid reset link.');
      return;
    }
    if (password.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final result = await AuthService.resetPassword(widget.token!, password);
    if (!mounted) return;
    setState(() => _loading = false);
    if (result.isSuccess) {
      setState(() => _done = true);
    } else if (result.isNetworkError) {
      setState(() => _error = result.errorMessage);
    } else {
      setState(() => _error = 'This reset link is invalid or has expired. Request a new one.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _done
                ? [
                    const Icon(Icons.check_circle_outline, size: 56, color: Colors.green),
                    const SizedBox(height: 16),
                    const Text('Your password has been reset. You can now log in.', textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('Go to login'),
                      ),
                    ),
                  ]
                : [
                    const Text('Choose a new password.', textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _passwordController,
                      decoration: const InputDecoration(labelText: 'New password', border: OutlineInputBorder()),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _confirmController,
                      decoration: const InputDecoration(labelText: 'Confirm password', border: OutlineInputBorder()),
                      obscureText: true,
                      onSubmitted: (_) => _loading ? null : _submit(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading ? const CircularProgressIndicator() : const Text('Reset password'),
                      ),
                    ),
                  ],
          ),
        ),
      ),
    );
  }
}