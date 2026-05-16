import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_service.dart';

class CoachDashboardScreen extends StatefulWidget {
  final int coachId;
  const CoachDashboardScreen({super.key, required this.coachId});

  @override
  State<CoachDashboardScreen> createState() => _CoachDashboardScreenState();
}

class _CoachDashboardScreenState extends State<CoachDashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _AthletesTab(coachId: widget.coachId),
      _WorkoutsTab(coachId: widget.coachId),
      _AvailabilityTab(coachId: widget.coachId),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coach Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ApiService.clearToken();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: tabs[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Athletes'),
          BottomNavigationBarItem(icon: Icon(Icons.sports), label: 'Workouts'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Availability'),
        ],
      ),
    );
  }
}

// ─── Athletes Tab ────────────────────────────────────────────────────────────

class _AthletesTab extends StatefulWidget {
  final int coachId;
  const _AthletesTab({required this.coachId});

  @override
  State<_AthletesTab> createState() => _AthletesTabState();
}

class _AthletesTabState extends State<_AthletesTab> {
  List<dynamic> _athletes = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final result = await ApiService.getAthletesByCoach(widget.coachId);
    if (!mounted) return;
    if (result.isSuccess) {
      setState(() { _athletes = result.data ?? []; _loading = false; });
    } else if (result.isUnauthorized) {
      await ApiService.clearToken();
      if (mounted) context.go('/login');
    } else {
      setState(() { _loading = false; _error = result.errorMessage; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _ErrorView(
        message: _error!,
        onRetry: _load,
        onLogout: () async {
          await ApiService.clearToken();
          if (context.mounted) context.go('/login');
        },
      );
    }
    if (_athletes.isEmpty) {
      return const Center(child: Text('No athletes assigned yet.', style: TextStyle(color: Colors.grey)));
    }
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _athletes.length,
          itemBuilder: (_, i) {
            final a = _athletes[i];
            return Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(a['name']),
                subtitle: Text(a['email']),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _assignAthlete,
        child: const Icon(Icons.person_add),
      ),
    );
  }

  Future<void> _assignAthlete() async {
    final allResult = await ApiService.getAllAthletes();
    if (!mounted) return;
    if (allResult.isUnauthorized) {
      await ApiService.clearToken();
      if (mounted) context.go('/login');
      return;
    }
    if (!allResult.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(allResult.errorMessage), backgroundColor: Colors.red),
      );
      return;
    }

    final myIds = _athletes.map((a) => a['id']).toSet();
    final unassigned = (allResult.data ?? []).where((a) => !myIds.contains(a['id'])).toList();

    if (unassigned.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No unassigned athletes available.')),
      );
      return;
    }

    final selected = await showDialog<dynamic>(
      context: context,
      builder: (_) => _AssignAthleteDialog(athletes: unassigned),
    );
    if (selected == null) return;

    final response = await ApiService.assignAthleteToCoach(
      selected['id'],
      selected['name'],
      selected['email'],
      widget.coachId,
    );
    if (!mounted) return;
    if (response.isUnauthorized) {
      await ApiService.clearToken();
      context.go('/login');
    } else if (!response.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.errorMessage), backgroundColor: Colors.red),
      );
    } else {
      _load();
    }
  }
}

// ─── Workouts Tab ────────────────────────────────────────────────────────────

class _WorkoutsTab extends StatefulWidget {
  final int coachId;
  const _WorkoutsTab({required this.coachId});

  @override
  State<_WorkoutsTab> createState() => _WorkoutsTabState();
}

class _WorkoutsTabState extends State<_WorkoutsTab> {
  List<dynamic> _workouts = [];
  List<dynamic> _athletes = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final results = await Future.wait([
      ApiService.getWorkoutsByCoach(widget.coachId),
      ApiService.getAthletesByCoach(widget.coachId),
    ]);
    if (!mounted) return;
    final workoutsResult = results[0];
    final athletesResult = results[1];
    if (workoutsResult.isUnauthorized) {
      await ApiService.clearToken();
      if (mounted) context.go('/login');
      return;
    }
    if (workoutsResult.isSuccess) {
      setState(() {
        _workouts = workoutsResult.data ?? [];
        _athletes = athletesResult.isSuccess ? (athletesResult.data ?? []) : [];
        _loading = false;
      });
    } else {
      setState(() { _loading = false; _error = workoutsResult.errorMessage; });
    }
  }

  Future<void> _createWorkout() async {
    if (_athletes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have no athletes assigned yet.')),
      );
      return;
    }
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _CreateWorkoutDialog(athletes: _athletes, coachId: widget.coachId),
    );
    if (result != null) {
      final response = await ApiService.createWorkout(result);
      if (!mounted) return;
      if (response.isUnauthorized) {
        await ApiService.clearToken();
        context.go('/login');
      } else if (!response.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.errorMessage), backgroundColor: Colors.red),
        );
      } else {
        _load();
      }
    }
  }

  Future<void> _deleteWorkout(int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete workout'),
        content: Text('Delete "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final response = await ApiService.deleteWorkout(id);
    if (!mounted) return;
    if (response.isUnauthorized) {
      await ApiService.clearToken();
      context.go('/login');
    } else if (!response.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.errorMessage), backgroundColor: Colors.red),
      );
    } else {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _ErrorView(
        message: _error!,
        onRetry: _load,
        onLogout: () async {
          await ApiService.clearToken();
          if (context.mounted) context.go('/login');
        },
      );
    }
    return Scaffold(
      body: _workouts.isEmpty
          ? const Center(child: Text('No workouts yet. Tap + to create one.', style: TextStyle(color: Colors.grey)))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _workouts.length,
                itemBuilder: (_, i) {
                  final w = _workouts[i];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.fitness_center),
                      title: Text(w['name']),
                      subtitle: Text('${w['type']} · ${w['scheduledDate']}\nAthlete: ${w['athleteName']}'),
                      isThreeLine: true,
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _deleteWorkout(w['id'], w['name']),
                      ),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createWorkout,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ─── Availability Tab ────────────────────────────────────────────────────────

class _AvailabilityTab extends StatefulWidget {
  final int coachId;
  const _AvailabilityTab({required this.coachId});

  @override
  State<_AvailabilityTab> createState() => _AvailabilityTabState();
}

class _AvailabilityTabState extends State<_AvailabilityTab> {
  List<dynamic> _availability = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final result = await ApiService.getCoachAvailability(widget.coachId);
    if (!mounted) return;
    if (result.isSuccess) {
      setState(() { _availability = result.data ?? []; _loading = false; });
    } else if (result.isUnauthorized) {
      await ApiService.clearToken();
      if (mounted) context.go('/login');
    } else {
      setState(() { _loading = false; _error = result.errorMessage; });
    }
  }

  Future<void> _addSlot() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _AddAvailabilityDialog(),
    );
    if (result != null) {
      result['coachId'] = widget.coachId;
      final response = await ApiService.addAvailability(result);
      if (!mounted) return;
      if (response.isUnauthorized) {
        await ApiService.clearToken();
        context.go('/login');
      } else if (!response.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.errorMessage), backgroundColor: Colors.red),
        );
      } else {
        _load();
      }
    }
  }

  Future<void> _deleteSlot(int id) async {
    final response = await ApiService.deleteAvailability(id);
    if (!mounted) return;
    if (response.isUnauthorized) {
      await ApiService.clearToken();
      context.go('/login');
    } else if (!response.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.errorMessage), backgroundColor: Colors.red),
      );
    } else {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _ErrorView(
        message: _error!,
        onRetry: _load,
        onLogout: () async {
          await ApiService.clearToken();
          if (context.mounted) context.go('/login');
        },
      );
    }
    return Scaffold(
      body: _availability.isEmpty
          ? const Center(child: Text('No availability slots yet. Tap + to add one.', style: TextStyle(color: Colors.grey)))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _availability.length,
                itemBuilder: (_, i) {
                  final slot = _availability[i];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: Text(slot['recurring']
                          ? '${slot['dayOfWeek']} (weekly)'
                          : slot['specificDate']),
                      subtitle: Text('${slot['startTime']} – ${slot['endTime']}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteSlot(slot['id']),
                      ),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addSlot,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ─── Create Workout Dialog ───────────────────────────────────────────────────

class _CreateWorkoutDialog extends StatefulWidget {
  final List<dynamic> athletes;
  final int coachId;
  const _CreateWorkoutDialog({required this.athletes, required this.coachId});

  @override
  State<_CreateWorkoutDialog> createState() => _CreateWorkoutDialogState();
}

class _CreateWorkoutDialogState extends State<_CreateWorkoutDialog> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  String _type = 'AMRAP';
  DateTime _date = DateTime.now();
  late dynamic _selectedAthlete;

  final _types = ['AMRAP', 'FOR_TIME', 'EMOM', 'STRENGTH', 'ENDURANCE'];

  @override
  void initState() {
    super.initState();
    _selectedAthlete = widget.athletes.first;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Workout'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(labelText: 'Description (optional)', border: OutlineInputBorder()),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
              items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<dynamic>(
              value: _selectedAthlete,
              decoration: const InputDecoration(labelText: 'Athlete', border: OutlineInputBorder()),
              items: widget.athletes
                  .map((a) => DropdownMenuItem(value: a, child: Text(a['name'])))
                  .toList(),
              onChanged: (v) => setState(() => _selectedAthlete = v),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Date: ${_date.toIso8601String().split('T').first}'),
              trailing: const Icon(Icons.date_range),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Name is required')),
              );
              return;
            }
            Navigator.pop(context, {
              'name': _nameController.text.trim(),
              'description': _descController.text.trim(),
              'type': _type,
              'scheduledDate': _date.toIso8601String().split('T').first,
              'athleteId': _selectedAthlete['id'],
              'coachId': widget.coachId,
            });
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

// ─── Add Availability Dialog ─────────────────────────────────────────────────

class _AddAvailabilityDialog extends StatefulWidget {
  const _AddAvailabilityDialog();

  @override
  State<_AddAvailabilityDialog> createState() => _AddAvailabilityDialogState();
}

class _AddAvailabilityDialogState extends State<_AddAvailabilityDialog> {
  bool _recurring = true;
  String _dayOfWeek = 'MONDAY';
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 11, minute: 0);

  final _days = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Availability'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            title: const Text('Recurring (weekly)'),
            value: _recurring,
            onChanged: (v) => setState(() => _recurring = v),
          ),
          if (_recurring)
            DropdownButtonFormField<String>(
              value: _dayOfWeek,
              decoration: const InputDecoration(labelText: 'Day of week'),
              items: _days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
              onChanged: (v) => setState(() => _dayOfWeek = v!),
            ),
          ListTile(
            title: Text('Start: ${_start.format(context)}'),
            trailing: const Icon(Icons.access_time),
            onTap: () async {
              final t = await showTimePicker(context: context, initialTime: _start);
              if (t != null) setState(() => _start = t);
            },
          ),
          ListTile(
            title: Text('End: ${_end.format(context)}'),
            trailing: const Icon(Icons.access_time),
            onTap: () async {
              final t = await showTimePicker(context: context, initialTime: _end);
              if (t != null) setState(() => _end = t);
            },
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, {
            'recurring': _recurring,
            'dayOfWeek': _recurring ? _dayOfWeek : null,
            'startTime': _formatTime(_start),
            'endTime': _formatTime(_end),
          }),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// ─── Assign Athlete Dialog ───────────────────────────────────────────────────

class _AssignAthleteDialog extends StatefulWidget {
  final List<dynamic> athletes;
  const _AssignAthleteDialog({required this.athletes});

  @override
  State<_AssignAthleteDialog> createState() => _AssignAthleteDialogState();
}

class _AssignAthleteDialogState extends State<_AssignAthleteDialog> {
  late dynamic _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.athletes.first;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assign Athlete'),
      content: DropdownButtonFormField<dynamic>(
        value: _selected,
        decoration: const InputDecoration(labelText: 'Athlete', border: OutlineInputBorder()),
        items: widget.athletes
            .map((a) => DropdownMenuItem(value: a, child: Text('${a['name']} (${a['email']})')))
            .toList(),
        onChanged: (v) => setState(() => _selected = v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('Assign'),
        ),
      ],
    );
  }
}

// ─── Shared error widget ─────────────────────────────────────────────────────

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
