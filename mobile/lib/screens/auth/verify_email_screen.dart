import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String? token;
  const VerifyEmailScreen({super.key, required this.token});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _loading = true;
  bool _success = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _verify();
  }

  Future<void> _verify() async {
    if (widget.token == null || widget.token!.isEmpty) {
      setState(() { _loading = false; _error = 'Missing or invalid verification link.'; });
      return;
    }
    final result = await AuthService.verifyEmail(widget.token!);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.isSuccess) {
        _success = true;
      } else if (result.isNetworkError) {
        _error = result.errorMessage;
      } else {
        _error = 'This verification link is invalid or has expired. Request a new one from the login screen.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Email')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _loading
                ? const [Center(child: CircularProgressIndicator())]
                : _success
                    ? [
                        const Icon(Icons.check_circle_outline, size: 56, color: Colors.green),
                        const SizedBox(height: 16),
                        const Text('Your email has been verified. You can now log in.', textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => context.go('/login'),
                          child: const Text('Go to login'),
                        ),
                      ]
                    : [
                        const Icon(Icons.error_outline, size: 56, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(_error ?? 'Verification failed.', textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        TextButton(
                          onPressed: () => context.go('/login'),
                          child: const Text('Back to login'),
                        ),
                      ],
          ),
        ),
      ),
    );
  }
}
