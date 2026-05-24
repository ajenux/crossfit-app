import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_client.dart';
import '../../services/ai_service.dart';

class ExerciseAssistantScreen extends StatefulWidget {
  const ExerciseAssistantScreen({super.key});

  @override
  State<ExerciseAssistantScreen> createState() => _ExerciseAssistantScreenState();
}

class _ExerciseAssistantScreenState extends State<ExerciseAssistantScreen> {
  final _controller = TextEditingController();
  Map<String, dynamic>? _result;
  bool _loading = false;
  String? _error;

  Future<void> _ask() async {
    final exercise = _controller.text.trim();
    if (exercise.isEmpty) return;
    setState(() { _loading = true; _error = null; _result = null; });
    final result = await AiService.explainExercise(exercise);
    if (!mounted) return;
    if (result.isUnauthorized) {
      await ApiClient.clearToken();
      if (mounted) context.go('/login');
      return;
    }
    setState(() {
      _loading = false;
      if (result.isSuccess) {
        _result = result.data;
      } else {
        _error = result.errorMessage;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exercise Assistant')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'Ask about an exercise...',
                      hintText: 'e.g. burpee, pull-up, deadlift',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _ask(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.send),
                  onPressed: _loading ? null : _ask,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            if (_result != null)
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_result!['gifUrl'] != null)
                        Center(
                          child: CachedNetworkImage(
                            imageUrl: _result!['gifUrl'],
                            height: 220,
                            placeholder: (_, __) => const CircularProgressIndicator(),
                            errorWidget: (_, __, ___) => const Icon(Icons.broken_image, size: 80),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Text(
                        _result!['explanation'] ?? '',
                        style: const TextStyle(fontSize: 15, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
