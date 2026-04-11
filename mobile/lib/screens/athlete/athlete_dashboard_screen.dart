import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_service.dart';

class AthleteDashboardScreen extends StatefulWidget {
  final int athleteId;
  const AthleteDashboardScreen({super.key, required this.athleteId});

  @override
  State<AthleteDashboardScreen> createState() => _AthleteDashboardScreenState();
}

class _AthleteDashboardScreenState extends State<AthleteDashboardScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await ApiService.getAthleteDashboard(widget.athleteId);
    setState(() { _data = data; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_data != null ? 'Hi, ${_data!['athleteName']}' : 'Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.fitness_center),
            tooltip: 'Ask AI',
            onPressed: () => context.go('/exercise'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ApiService.clearToken();
              if (mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _data == null
              ? const Center(child: Text('Failed to load dashboard'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_data!['coachName'] != null)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.person),
                            title: const Text('Your Coach'),
                            subtitle: Text(_data!['coachName']),
                          ),
                        ),
                      const SizedBox(height: 16),
                      const Text('Coach Availability', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...(_data!['coachAvailability'] as List).map((slot) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.calendar_today),
                          title: Text(slot['recurring']
                              ? '${slot['dayOfWeek']} (weekly)'
                              : slot['specificDate']),
                          subtitle: Text('${slot['startTime']} – ${slot['endTime']}'),
                        ),
                      )),
                      const SizedBox(height: 16),
                      const Text('Your Workouts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...(_data!['workouts'] as List).map((w) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.sports),
                          title: Text(w['name']),
                          subtitle: Text('${w['type']} · ${w['scheduledDate']}'),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      )),
                    ],
                  ),
                ),
    );
  }
}
