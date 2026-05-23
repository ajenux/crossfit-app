import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_client.dart';
import '../../services/dashboard_service.dart';

class AthleteDashboardScreen extends StatefulWidget {
  final int athleteId;
  const AthleteDashboardScreen({super.key, required this.athleteId});

  @override
  State<AthleteDashboardScreen> createState() => _AthleteDashboardScreenState();
}

class _AthleteDashboardScreenState extends State<AthleteDashboardScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final result = await DashboardService.getAthleteDashboard(widget.athleteId);
    if (!mounted) return;
    if (result.isSuccess) {
      setState(() { _data = result.data; _loading = false; });
    } else if (result.isUnauthorized) {
      await ApiClient.clearToken();
      if (mounted) context.go('/login');
    } else {
      setState(() { _loading = false; _error = result.errorMessage; });
    }
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
              await ApiClient.clearToken();
              if (mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(
                  message: _error!,
                  onRetry: _load,
                  onLogout: () async {
                    await ApiClient.clearToken();
                    if (mounted) context.go('/login');
                  },
                )
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
                      if ((_data!['coachAvailability'] as List).isEmpty)
                        const Text('No availability slots yet.', style: TextStyle(color: Colors.grey))
                      else
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
                      if ((_data!['workouts'] as List).isEmpty)
                        const Text('No workouts assigned yet.', style: TextStyle(color: Colors.grey))
                      else
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

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback? onLogout;

  const _ErrorView({required this.message, required this.onRetry, this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
            if (onLogout != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onLogout,
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
