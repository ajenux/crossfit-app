import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_client.dart';
import '../../services/athlete_service.dart';
import '../../services/workout_service.dart';
import '../../services/availability_service.dart';
import '../../services/sheets_service.dart';

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
      _ImportTab(coachId: widget.coachId),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coach Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ApiClient.clearToken();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: tabs[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Athletes'),
          BottomNavigationBarItem(icon: Icon(Icons.sports), label: 'Workouts'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Availability'),
          BottomNavigationBarItem(icon: Icon(Icons.table_chart), label: 'Import'),
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
    final result = await AthleteService.getAthletesByCoach(widget.coachId);
    if (!mounted) return;
    if (result.isSuccess) {
      setState(() { _athletes = result.data ?? []; _loading = false; });
    } else if (result.isUnauthorized) {
      await ApiClient.clearToken();
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
          await ApiClient.clearToken();
          if (context.mounted) context.go('/login');
        },
      );
    }
    return Scaffold(
      body: _athletes.isEmpty
          ? const Center(child: Text('No athletes assigned yet. Tap + to assign one.', style: TextStyle(color: Colors.grey)))
          : RefreshIndicator(
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
    final allResult = await AthleteService.getAllAthletes();
    if (!mounted) return;
    if (allResult.isUnauthorized) {
      await ApiClient.clearToken();
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

    final response = await AthleteService.assignAthleteToCoach(
      selected['id'],
      selected['name'],
      selected['email'],
      widget.coachId,
    );
    if (!mounted) return;
    if (response.isUnauthorized) {
      await ApiClient.clearToken();
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
      WorkoutService.getWorkoutsByCoach(widget.coachId),
      AthleteService.getAthletesByCoach(widget.coachId),
    ]);
    if (!mounted) return;
    final workoutsResult = results[0];
    final athletesResult = results[1];
    if (workoutsResult.isUnauthorized) {
      await ApiClient.clearToken();
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
      final response = await WorkoutService.createWorkout(result);
      if (!mounted) return;
      if (response.isUnauthorized) {
        await ApiClient.clearToken();
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
    final response = await WorkoutService.deleteWorkout(id);
    if (!mounted) return;
    if (response.isUnauthorized) {
      await ApiClient.clearToken();
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
          await ApiClient.clearToken();
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
    final result = await AvailabilityService.getCoachAvailability(widget.coachId);
    if (!mounted) return;
    if (result.isSuccess) {
      setState(() { _availability = result.data ?? []; _loading = false; });
    } else if (result.isUnauthorized) {
      await ApiClient.clearToken();
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
      final response = await AvailabilityService.addAvailability(result);
      if (!mounted) return;
      if (response.isUnauthorized) {
        await ApiClient.clearToken();
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
    final response = await AvailabilityService.deleteAvailability(id);
    if (!mounted) return;
    if (response.isUnauthorized) {
      await ApiClient.clearToken();
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
          await ApiClient.clearToken();
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

// ─── Import Tab ──────────────────────────────────────────────────────────────

class _ImportTab extends StatefulWidget {
  final int coachId;
  const _ImportTab({required this.coachId});

  @override
  State<_ImportTab> createState() => _ImportTabState();
}

class _ImportTabState extends State<_ImportTab> {
  List<dynamic> _weeks = [];
  List<dynamic> _athletes = [];
  bool _loading = true;
  String? _error;

  dynamic _selectedWeek;
  // Each entry: {'athlete': obj, 'weightIndex': 0 (heavy) | 1 (light)}
  List<Map<String, dynamic>> _selectedAthletes = [];
  DateTime _startDate = DateTime.now();
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final results = await Future.wait([
      SheetsService.getSheetWeeks(),
      AthleteService.getAthletesByCoach(widget.coachId),
    ]);
    if (!mounted) return;
    final weeksResult = results[0];
    final athletesResult = results[1];

    if (weeksResult.isUnauthorized) {
      await ApiClient.clearToken();
      if (mounted) context.go('/login');
      return;
    }
    if (!weeksResult.isSuccess) {
      setState(() { _loading = false; _error = weeksResult.errorMessage; });
      return;
    }

    final weeks = weeksResult.data ?? [];
    final athletes = athletesResult.isSuccess ? (athletesResult.data ?? []) : [];
    setState(() {
      _weeks = weeks;
      _athletes = athletes;
      _selectedWeek = weeks.isNotEmpty ? weeks.first : null;
      _selectedAthletes = [
        if (athletes.isNotEmpty) {'athlete': athletes.first, 'weightIndex': 0},
        if (athletes.length > 1) {'athlete': athletes[1], 'weightIndex': 1},
      ];
      _loading = false;
    });
  }

  Future<void> _import() async {
    if (_selectedWeek == null || _selectedAthletes.isEmpty) return;
    setState(() => _importing = true);
    final result = await SheetsService.importSheetWeek({
      'weekNumber': _selectedWeek['weekNumber'],
      'coachId': widget.coachId,
      'startDate': _startDate.toIso8601String().split('T').first,
      'athletes': _selectedAthletes.map((e) => {
        'athleteId': e['athlete']['id'],
        'weightIndex': e['weightIndex'],
      }).toList(),
    });
    if (!mounted) return;
    setState(() => _importing = false);
    if (result.isUnauthorized) {
      await ApiClient.clearToken();
      if (mounted) context.go('/login');
    } else if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage), backgroundColor: Colors.red),
      );
    } else {
      final data = result.data!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Imported ${data['workoutsCreated']} workouts for week ${data['weekNumber']}'),
          backgroundColor: Colors.green,
        ),
      );
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
          await ApiClient.clearToken();
          if (context.mounted) context.go('/login');
        },
      );
    }

    if (_weeks.isEmpty) {
      return const Center(
        child: Text('No weeks found in the sheet.', style: TextStyle(color: Colors.grey)),
      );
    }
    if (_athletes.isEmpty) {
      return const Center(
        child: Text('No athletes assigned yet. Assign athletes first.', style: TextStyle(color: Colors.grey)),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Import from Google Sheets', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Select a week and assign athletes to create workouts automatically.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          DropdownButtonFormField<dynamic>(
            value: _selectedWeek,
            decoration: const InputDecoration(labelText: 'Week', border: OutlineInputBorder()),
            items: _weeks.map((w) => DropdownMenuItem(
              value: w,
              child: Text('Week ${w['weekNumber']} · ${w['dayCount']} days'),
            )).toList(),
            onChanged: (v) => setState(() => _selectedWeek = v),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Athletes', style: TextStyle(fontWeight: FontWeight.w600)),
              TextButton.icon(
                onPressed: _athletes.isEmpty ? null : () {
                  setState(() => _selectedAthletes.add({
                    'athlete': _athletes.first,
                    'weightIndex': 0,
                  }));
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add athlete'),
              ),
            ],
          ),
          ..._selectedAthletes.asMap().entries.map((entry) {
            final i = entry.key;
            final sel = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<dynamic>(
                      value: sel['athlete'],
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: _athletes.map((a) => DropdownMenuItem(value: a, child: Text(a['name']))).toList(),
                      onChanged: (v) => setState(() => _selectedAthletes[i]['athlete'] = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: sel['weightIndex'] as int,
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Heavy')),
                      DropdownMenuItem(value: 1, child: Text('Light')),
                    ],
                    onChanged: (v) => setState(() => _selectedAthletes[i]['weightIndex'] = v),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                    onPressed: () => setState(() => _selectedAthletes.removeAt(i)),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Start date: ${_startDate.toIso8601String().split('T').first}'),
            subtitle: const Text('Day 1 = this date, Day 2 = next day, etc.'),
            trailing: const Icon(Icons.date_range),
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _startDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) setState(() => _startDate = picked);
            },
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _importing ? null : _import,
            icon: _importing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.download),
            label: Text(_importing ? 'Importing...' : 'Import Week'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
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
