import 'package:flutter/material.dart';
import '../../models/workout.dart';
import '../../services/workout_service.dart';
import 'workout_form_screen.dart';

class WorkoutListScreen extends StatefulWidget {
  const WorkoutListScreen({super.key});

  @override
  State<WorkoutListScreen> createState() => _WorkoutListScreenState();
}

class _WorkoutListScreenState extends State<WorkoutListScreen> {
  late Future<List<Workout>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() => _future = WorkoutService.findAll());
  }

  Future<void> _delete(Workout workout) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Workout'),
        content: Text('Delete "${workout.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await WorkoutService.delete(workout.id);
      _reload();
    }
  }

  Color _typeColor(WorkoutType type) {
    switch (type) {
      case WorkoutType.AMRAP:
        return Colors.orange;
      case WorkoutType.FOR_TIME:
        return Colors.red;
      case WorkoutType.EMOM:
        return Colors.blue;
      case WorkoutType.STRENGTH:
        return Colors.purple;
      case WorkoutType.ENDURANCE:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Workout>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final workouts = snap.data!;
          if (workouts.isEmpty) {
            return const Center(child: Text('No workouts yet.'));
          }
          return ListView.builder(
            itemCount: workouts.length,
            itemBuilder: (context, i) {
              final w = workouts[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: _typeColor(w.type),
                  child: Text(
                    w.type.name.substring(0, 1),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(w.name),
                subtitle: Text(
                  '${w.scheduledDate} · ${w.athleteName} · Coach: ${w.coachName}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => WorkoutFormScreen(workout: w),
                          ),
                        );
                        _reload();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _delete(w),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WorkoutFormScreen()),
          );
          _reload();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}