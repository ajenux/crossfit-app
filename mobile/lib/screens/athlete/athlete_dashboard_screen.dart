import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_client.dart';
import '../../services/dashboard_service.dart';
import '../../services/notification_service.dart';

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
