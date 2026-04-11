import 'package:flutter/material.dart';
import '../../models/athlete.dart';
import '../../services/athlete_service.dart';
import 'athlete_form_screen.dart';

class AthleteListScreen extends StatefulWidget {
  const AthleteListScreen({super.key});

  @override
  State<AthleteListScreen> createState() => _AthleteListScreenState();
}

class _AthleteListScreenState extends State<AthleteListScreen> {
  late Future<List<Athlete>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() => _future = AthleteService.findAll());
  }

  Future<void> _delete(Athlete athlete) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Athlete'),
        content: Text('Delete ${athlete.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await AthleteService.delete(athlete.id);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Athlete>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final athletes = snap.data!;
          if (athletes.isEmpty) {
            return const Center(child: Text('No athletes yet.'));
          }
          return ListView.builder(
            itemCount: athletes.length,
            itemBuilder: (context, i) {
              final a = athletes[i];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.directions_run)),
                title: Text(a.name),
                subtitle: Text(
                  a.coachName != null ? '${a.email} · Coach: ${a.coachName}' : a.email,
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
                            builder: (_) => AthleteFormScreen(athlete: a),
                          ),
                        );
                        _reload();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _delete(a),
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
            MaterialPageRoute(builder: (_) => const AthleteFormScreen()),
          );
          _reload();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}