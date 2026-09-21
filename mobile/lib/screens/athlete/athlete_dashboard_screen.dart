import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_client.dart';
import '../../services/dashboard_service.dart';
import '../../services/notification_service.dart';
import 'workout_detail_screen.dart';

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
  late DateTime _viewedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _viewedMonth = DateTime(now.year, now.month, 1);
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

  static final _rxcPattern = RegExp(r'\b(\d+\s*RxC)\b', caseSensitive: false);

  String? _extractRxC(List<dynamic> workouts) {
    final today = DateTime.now();
    final sorted = [...workouts]..sort((a, b) {
        final da = DateTime.tryParse(a['scheduledDate'] as String? ?? '') ?? DateTime(2000);
        final db = DateTime.tryParse(b['scheduledDate'] as String? ?? '') ?? DateTime(2000);
        return da.difference(today).abs().compareTo(db.difference(today).abs());
      });
    for (final w in sorted) {
      final desc = (w['description'] as String?) ?? '';
      final match = _rxcPattern.firstMatch(desc);
      if (match != null) return match.group(1);
    }
    return null;
  }

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  String _monthLabel(DateTime d) => '${_monthNames[d.month - 1]} ${d.year}';

  // Monday of the week containing [date].
  DateTime _weekMonday(DateTime date) => DateTime(date.year, date.month, date.day)
      .subtract(Duration(days: date.weekday - 1));

  static const _shortMonthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  String _shortDate(DateTime d) => '${_shortMonthNames[d.month - 1]} ${d.day}';

  List<Widget> _buildWorkoutSections() {
    final now = DateTime.now();
    final currentMonday = _weekMonday(now);
    final isCurrentMonth = _viewedMonth.year == now.year && _viewedMonth.month == now.month;

    final monthWorkouts = (_data!['workouts'] as List).where((w) {
      final d = DateTime.tryParse(w['scheduledDate'] as String? ?? '');
      return d != null && d.year == _viewedMonth.year && d.month == _viewedMonth.month;
    }).toList()
      ..sort((a, b) => (a['scheduledDate'] as String).compareTo(b['scheduledDate'] as String));

    // Group by the Monday of each workout's calendar week, hiding weeks after
    // the current one when viewing the current month (not yet relevant/programmed).
    final Map<DateTime, List<dynamic>> byWeek = {};
    for (final w in monthWorkouts) {
      final d = DateTime.parse(w['scheduledDate'] as String);
      final monday = _weekMonday(d);
      if (isCurrentMonth && monday.isAfter(currentMonday)) continue;
      byWeek.putIfAbsent(monday, () => []).add(w);
    }

    if (byWeek.isEmpty) {
      return [const Text('No workouts this month.', style: TextStyle(color: Colors.grey))];
    }

    final mondays = byWeek.keys.toList()..sort();
    final widgets = <Widget>[];
    for (final monday in mondays) {
      final weekWorkouts = byWeek[monday]!;
      // Prefer the coach's own "Semana N" label from the sheet; fall back to
      // the real date range for manually-created (non-sheet) workouts.
      String? label;
      for (final w in weekWorkouts) {
        final l = w['sheetsWeekLabel'] as String?;
        if (l != null && l.isNotEmpty) { label = l; break; }
      }
      label ??= 'Week of ${_shortDate(monday)}';

      widgets.add(Card(
        margin: const EdgeInsets.only(top: 8),
        child: ExpansionTile(
          title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          children: weekWorkouts.map((w) => _WorkoutCard(
                workout: w as Map<String, dynamic>,
                onUpdated: (updated) => _onWorkoutUpdated(updated),
              )).toList(),
        ),
      ));
    }
    return widgets;
  }

  Widget _buildMonthNav() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Previous month',
          onPressed: () => setState(
              () => _viewedMonth = DateTime(_viewedMonth.year, _viewedMonth.month - 1, 1)),
        ),
        Text(_monthLabel(_viewedMonth), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Next month',
          onPressed: () => setState(
              () => _viewedMonth = DateTime(_viewedMonth.year, _viewedMonth.month + 1, 1)),
        ),
      ],
    );
  }

  void _onWorkoutUpdated(Map<String, dynamic> updated) {
    setState(() {
      final workouts = _data!['workouts'] as List;
      final idx = workouts.indexWhere((w) => w['id'] == updated['id']);
      if (idx != -1) {
        workouts[idx] = updated;
        final done = workouts.where((w) => w['completed'] == true).length;
        _data = {..._data!, 'completedWorkouts': done};
      }
    });
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
                      ...() {
                        final rxc = _extractRxC(_data!['workouts'] as List);
                        return rxc != null
                            ? [const SizedBox(height: 16), _RxCCard(label: rxc), const SizedBox(height: 16)]
                            : [const SizedBox(height: 16)];
                      }(),
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
                      _buildMonthNav(),
                      const SizedBox(height: 8),
                      if ((_data!['workouts'] as List).isEmpty)
                        const Text('No workouts assigned yet.', style: TextStyle(color: Colors.grey))
                      else
                        ..._buildWorkoutSections(),
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
  final void Function(Map<String, dynamic>) onUpdated;
  const _WorkoutCard({required this.workout, required this.onUpdated});

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
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final updated = await Navigator.push<Map<String, dynamic>>(
            context,
            MaterialPageRoute(
              builder: (_) => WorkoutDetailScreen(workout: workout),
            ),
          );
          if (updated != null) onUpdated(updated);
        },
      ),
    );
  }
}

class _RxCCard extends StatelessWidget {
  final String label;
  const _RxCCard({required this.label});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.trending_up, size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Esta semana',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onPrimaryContainer.withAlpha(180))),
                Text(label,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer)),
              ],
            ),
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
