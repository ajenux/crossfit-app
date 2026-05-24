import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_client.dart';
import '../../services/dashboard_service.dart';
import '../../services/notification_service.dart';
import '../../services/workout_service.dart';

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
  List<dynamic> _notifications = [];
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final results = await Future.wait([
      DashboardService.getAthleteDashboard(widget.athleteId),
      NotificationService.getNotifications(),
    ]);
    if (!mounted) return;
    final dashResult = results[0] as ApiResult<Map<String, dynamic>>;
    final notifResult = results[1] as ApiResult<List<dynamic>>;
    if (dashResult.isUnauthorized) {
      await ApiClient.clearToken();
      if (mounted) context.go('/login');
      return;
    }
    if (dashResult.isSuccess) {
      final notifications = notifResult.isSuccess ? (notifResult.data ?? []) : [];
      setState(() {
        _data = dashResult.data;
        _notifications = notifications;
        _unreadCount = notifications.where((n) => n['read'] == false).length;
        _loading = false;
      });
    } else {
      setState(() { _loading = false; _error = dashResult.errorMessage; });
    }
  }

  Future<void> _toggleWorkout(Map<String, dynamic> workout, bool completed) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(completed ? 'Mark as completed?' : 'Mark as pending?'),
        content: Text(workout['name'] as String),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(completed ? 'Complete' : 'Undo'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final result = await WorkoutService.updateCompletion(workout['id'] as int, completed);
    if (!mounted) return;
    if (result.isSuccess) {
      setState(() {
        final workouts = _data!['workouts'] as List;
        final idx = workouts.indexWhere((w) => w['id'] == workout['id']);
        if (idx != -1) {
          workouts[idx] = {...workout, 'completed': completed};
          final done = workouts.where((w) => w['completed'] == true).length;
          _data = {..._data!, 'completedWorkouts': done};
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update workout status')),
      );
    }
  }

  Future<void> _openNotifications() async {
    if (_unreadCount > 0) {
      NotificationService.markAllRead();
      setState(() {
        _notifications = _notifications.map((n) => {...n, 'read': true}).toList();
        _unreadCount = 0;
      });
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _NotificationsSheet(notifications: _notifications),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_data != null ? 'Hi, ${_data!['athleteName']}' : 'Dashboard'),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: _unreadCount > 0,
              label: Text('$_unreadCount'),
              child: const Icon(Icons.notifications_outlined),
            ),
            tooltip: 'Notifications',
            onPressed: _openNotifications,
          ),
          IconButton(
            icon: const Icon(Icons.fitness_center),
            tooltip: 'Ask AI',
            onPressed: () => context.push('/exercise'),
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
                      _ProgressCard(
                        total: (_data!['totalWorkouts'] as num).toInt(),
                        completed: (_data!['completedWorkouts'] as num).toInt(),
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
                        ...(_data!['workouts'] as List).map((w) => _WorkoutCard(
                          workout: w as Map<String, dynamic>,
                          onToggle: (completed) => _toggleWorkout(w, completed),
                        )),
                    ],
                  ),
                ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final int total;
  final int completed;
  const _ProgressCard({required this.total, required this.completed});

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : completed / total;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Progress', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('$completed / $total', style: const TextStyle(fontSize: 16)),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 4),
            Text('${(pct * 100).toInt()}% completed',
                style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  final Map<String, dynamic> workout;
  final void Function(bool) onToggle;
  const _WorkoutCard({required this.workout, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final isCompleted = workout['completed'] == true;
    return Card(
      child: ListTile(
        leading: Icon(
          isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
          color: isCompleted ? Colors.green : Colors.grey,
        ),
        title: Text(
          workout['name'] as String,
          style: TextStyle(
            decoration: isCompleted ? TextDecoration.lineThrough : null,
            color: isCompleted ? Colors.grey : null,
          ),
        ),
        subtitle: Text('${workout['type']} · ${workout['scheduledDate']}'),
        trailing: TextButton(
          onPressed: () => onToggle(!isCompleted),
          child: Text(isCompleted ? 'Undo' : 'Done'),
        ),
      ),
    );
  }
}

class _NotificationsSheet extends StatelessWidget {
  final List<dynamic> notifications;
  const _NotificationsSheet({required this.notifications});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(Icons.notifications),
              SizedBox(width: 8),
              Text('Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const Divider(height: 1),
        if (notifications.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Text('No notifications yet.', style: TextStyle(color: Colors.grey)),
          )
        else
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final n = notifications[i];
                final isUnread = n['read'] == false;
                return ListTile(
                  leading: Icon(
                    Icons.circle,
                    size: 10,
                    color: isUnread ? Theme.of(context).colorScheme.primary : Colors.transparent,
                  ),
                  title: Text(
                    n['message'] as String,
                    style: TextStyle(fontWeight: isUnread ? FontWeight.bold : FontWeight.normal),
                  ),
                  subtitle: Text(
                    _formatDate(n['createdAt'] as String),
                    style: const TextStyle(fontSize: 12),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
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
