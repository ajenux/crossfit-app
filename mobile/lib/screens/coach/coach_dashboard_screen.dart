import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_client.dart';
import '../../services/athlete_service.dart';
import '../../services/workout_service.dart';
import '../../services/availability_service.dart';
import '../../services/sheets_service.dart';
import '../../services/import_config_service.dart';

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
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 0;
  String? _error;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _page = 0; _hasMore = true; });
    final result = await AthleteService.getAthletesByCoach(widget.coachId, page: 0);
    if (!mounted) return;
    if (result.isSuccess) {
      setState(() {
        _athletes = result.data ?? [];
        _hasMore = !result.isLastPage;
        _page = 1;
        _loading = false;
      });
    } else if (result.isUnauthorized) {
      await ApiClient.clearToken();
      if (mounted) context.go('/login');
    } else {
      setState(() { _loading = false; _error = result.errorMessage; });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    final result = await AthleteService.getAthletesByCoach(widget.coachId, page: _page);
    if (!mounted) return;
    if (result.isSuccess) {
      setState(() {
        _athletes.addAll(result.data ?? []);
        _hasMore = !result.isLastPage;
        _page++;
        _loadingMore = false;
      });
    } else {
      setState(() => _loadingMore = false);
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
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _athletes.length + (_loadingMore ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i == _athletes.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
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
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 0;
  String? _error;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _page = 0; _hasMore = true; });
    final results = await Future.wait([
      WorkoutService.getWorkoutsByCoach(widget.coachId, page: 0),
      AthleteService.getAthletesByCoach(widget.coachId, size: 100),
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
        _hasMore = !workoutsResult.isLastPage;
        _page = 1;
        _loading = false;
      });
    } else {
      setState(() { _loading = false; _error = workoutsResult.errorMessage; });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    final result = await WorkoutService.getWorkoutsByCoach(widget.coachId, page: _page);
    if (!mounted) return;
    if (result.isSuccess) {
      setState(() {
        _workouts.addAll(result.data ?? []);
        _hasMore = !result.isLastPage;
        _page++;
        _loadingMore = false;
      });
    } else {
      setState(() => _loadingMore = false);
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
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _workouts.length + (_loadingMore ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i == _workouts.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
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
  List<String> _tabs = [];
  String? _selectedTab;
  List<dynamic> _weeks = [];
  List<dynamic> _athletes = [];
  bool _loading = true;
  bool _loadingWeeks = false;
  String? _error;

  dynamic _selectedWeek;
  List<Map<String, dynamic>> _selectedAthletes = [];
  DateTime _startDate = DateTime.now();
  bool _importing = false;

  static const _dayNames = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  // Default: Mon / Tue / Wed / Fri
  List<bool> _selectedDays = [true, true, true, false, true, false, false];

  bool _autoImportEnabled = false;
  String? _lastImportedMonday;

  static const _prefKey = 'training_days';

  static const _monthMap = {
    'enero': 1,
    'feb': 2, 'febrero': 2,
    'mar': 3, 'marzo': 3, 'marz': 3,
    'abr': 4, 'abril': 4, 'abri': 4,
    'may': 5, 'mayo': 5, 'maio': 5,
    'jun': 6, 'junio': 6,
    'jul': 7, 'julio': 7,
    'ago': 8, 'agosto': 8, 'agost': 8,
    'sep': 9, 'sept': 9, 'septiembre': 9,
    'oct': 10, 'octu': 10, 'octubre': 10,
    'nov': 11, 'noviembre': 11,
    'dic': 12, 'diciembre': 12,
  };

  String _formatDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  void _updateStartDate() {
    if (_selectedTab == null || _selectedWeek == null) return;
    final month = _monthMap[_selectedTab!.toLowerCase().trim()];
    if (month == null) return;
    final year = DateTime.now().year;
    final firstOfMonth = DateTime(year, month, 1);
    final daysToMonday = (DateTime.monday - firstOfMonth.weekday + 7) % 7;
    final firstMonday = firstOfMonth.add(Duration(days: daysToMonday));
    final weekNum = (_selectedWeek['weekNumber'] as int) - 1;
    setState(() => _startDate = firstMonday.add(Duration(days: weekNum * 7)));
  }

  Future<void> _loadTrainingDays() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null && saved.isNotEmpty) {
      final savedNames = saved.split(',');
      setState(() {
        _selectedDays = _dayNames.map((d) => savedNames.contains(d)).toList();
      });
    }
  }

  Future<void> _saveTrainingDays() async {
    final prefs = await SharedPreferences.getInstance();
    final selected = _dayNames.where((d) => _selectedDays[_dayNames.indexOf(d)]).join(',');
    await prefs.setString(_prefKey, selected);
  }

  List<String> get _orderedTrainingDays =>
      _dayNames.where((d) => _selectedDays[_dayNames.indexOf(d)]).toList();

  @override
  void initState() {
    super.initState();
    _loadTrainingDays();
    _load();
  }

  // Returns the Monday of the week that contains [date].
  // Using the week's Monday (not today) ensures a Friday in month N+1
  // is still treated as part of month N's last week.
  DateTime _weekMonday(DateTime date) =>
      date.subtract(Duration(days: date.weekday - 1));

  // Finds the tab name whose month number matches [monday.month].
  String? _tabForMonday(List<String> tabs, DateTime monday) {
    String? result;
    for (final tab in tabs) {
      if (_monthMap[tab.toLowerCase().trim()] == monday.month) result = tab;
    }
    return result;
  }

  // Returns the 1-based week number of [monday] within its month.
  int _weekNumberInMonth(DateTime monday) {
    final firstOfMonth = DateTime(monday.year, monday.month, 1);
    final daysToFirstMonday = (DateTime.monday - firstOfMonth.weekday + 7) % 7;
    final firstMonday = firstOfMonth.add(Duration(days: daysToFirstMonday));
    return ((monday.difference(firstMonday).inDays) / 7).floor() + 1;
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final results = await Future.wait([
      SheetsService.getSheetTabs(),
      AthleteService.getAthletesByCoach(widget.coachId),
    ]);
    if (!mounted) return;
    final tabsResult = results[0] as ApiResult<List<dynamic>>;
    final athletesResult = results[1] as ApiResult<List<dynamic>>;

    if (tabsResult.isUnauthorized) {
      await ApiClient.clearToken();
      if (mounted) context.go('/login');
      return;
    }
    if (!tabsResult.isSuccess) {
      setState(() { _loading = false; _error = tabsResult.errorMessage; });
      return;
    }

    final tabs = (tabsResult.data ?? []).map((t) => t.toString()).toList();
    final athletes = athletesResult.isSuccess ? (athletesResult.data ?? []) : [];

    // Load saved auto-import config from server.
    final configResult = await ImportConfigService.getConfig(widget.coachId);
    if (configResult.isSuccess) {
      final cfg = configResult.data!;
      final savedDays = (cfg['trainingDays'] as List?)?.map((d) => d.toString()).toList();
      if (savedDays != null) {
        _selectedDays = _dayNames.map((d) => savedDays.contains(d)).toList();
      }
      _autoImportEnabled = cfg['enabled'] as bool? ?? false;
      _lastImportedMonday = cfg['lastImportedMonday'] as String?;
    }

    // Auto-select the tab that corresponds to the current week's Monday.
    final today = DateTime.now();
    final currentMonday = _weekMonday(today);
    final autoTab = _tabForMonday(tabs, currentMonday) ?? (tabs.isNotEmpty ? tabs.first : null);

    setState(() {
      _tabs = tabs;
      _selectedTab = autoTab;
      _athletes = athletes;
      _selectedAthletes = [
        if (athletes.isNotEmpty) {'athlete': athletes.first, 'weightIndex': 0},
        if (athletes.length > 1) {'athlete': athletes[1], 'weightIndex': 1},
      ];
      _loading = false;
    });

    if (autoTab != null) await _loadWeeks(autoTab, autoSelectMonday: currentMonday);
  }

  Future<void> _saveAutoImportConfig(bool enabled) async {
    final result = await ImportConfigService.saveConfig({
      'coachId': widget.coachId,
      'enabled': enabled,
      'trainingDays': _orderedTrainingDays,
      'athletes': _selectedAthletes.map((e) => {
        'athleteId': e['athlete']['id'],
        'weightIndex': e['weightIndex'],
      }).toList(),
    });
    if (!mounted) return;
    if (result.isSuccess) {
      setState(() {
        _autoImportEnabled = enabled;
        _lastImportedMonday = result.data!['lastImportedMonday'] as String?;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(enabled ? 'Auto-import enabled. Workouts will be created every Monday.' : 'Auto-import disabled.'),
        backgroundColor: enabled ? Colors.green : Colors.grey,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _loadWeeks(String tab, {DateTime? autoSelectMonday}) async {
    setState(() { _loadingWeeks = true; _weeks = []; _selectedWeek = null; });
    final result = await SheetsService.getSheetWeeks(tab);
    if (!mounted) return;
    final weeks = result.isSuccess ? (result.data ?? []) : [];

    dynamic selected;
    if (autoSelectMonday != null && weeks.isNotEmpty) {
      final targetNum = _weekNumberInMonth(autoSelectMonday);
      selected = weeks.firstWhere(
        (w) => w['weekNumber'] == targetNum,
        orElse: () => weeks.last,
      );
    } else {
      selected = weeks.isNotEmpty ? weeks.first : null;
    }

    setState(() {
      _weeks = weeks;
      _selectedWeek = selected;
      _loadingWeeks = false;
    });
    _updateStartDate();
  }

  Future<void> _clearWorkouts() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear all workouts'),
        content: const Text('This will permanently delete all workouts assigned by you. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete all', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result = await WorkoutService.deleteAllByCoach(widget.coachId);
    if (!mounted) return;
    if (result.isUnauthorized) {
      await ApiClient.clearToken();
      if (mounted) context.go('/login');
    } else if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage), backgroundColor: Colors.red),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All workouts deleted.'), backgroundColor: Colors.orange),
      );
    }
  }

  Future<void> _import() async {
    if (_selectedWeek == null || _selectedAthletes.isEmpty) return;
    setState(() => _importing = true);
    final result = await SheetsService.importSheetWeek({
      'sheetName': _selectedTab,
      'weekNumber': _selectedWeek['weekNumber'],
      'coachId': widget.coachId,
      'startDate': _startDate.toIso8601String().split('T').first,
      'trainingDays': _orderedTrainingDays,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text('Import from Google Sheets', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: _clearWorkouts,
                icon: const Icon(Icons.delete_sweep, color: Colors.red),
                label: const Text('Clear all', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Select a month and week, then assign athletes to create workouts.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            value: _selectedTab,
            decoration: const InputDecoration(labelText: 'Month', border: OutlineInputBorder()),
            items: _tabs.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (v) {
              if (v != null && v != _selectedTab) {
                setState(() => _selectedTab = v);
                _loadWeeks(v);
              }
            },
          ),
          const SizedBox(height: 16),
          if (_loadingWeeks)
            const Center(child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: CircularProgressIndicator(),
            ))
          else
          DropdownButtonFormField<dynamic>(
            value: _selectedWeek,
            decoration: const InputDecoration(labelText: 'Week', border: OutlineInputBorder()),
            items: _weeks.map((w) => DropdownMenuItem(
              value: w,
              child: Text('Week ${w['weekNumber']} · ${w['dayCount']} days'),
            )).toList(),
            onChanged: (v) { setState(() => _selectedWeek = v); _updateStartDate(); },
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
          const Text('Training days', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: List.generate(_dayLabels.length, (i) {
              return FilterChip(
                label: Text(_dayLabels[i]),
                selected: _selectedDays[i],
                onSelected: (val) {
                  setState(() => _selectedDays[i] = val);
                  _saveTrainingDays();
                },
              );
            }),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Start date: ${_formatDate(_startDate)}'),
            subtitle: const Text('Auto-calculated · tap to override'),
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
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: _autoImportEnabled ? Colors.green : Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SwitchListTile(
              title: const Text('Auto-import every week', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                _autoImportEnabled
                    ? (_lastImportedMonday != null
                        ? 'Last imported: week of $_lastImportedMonday'
                        : 'Runs daily at 6am · saves current config')
                    : 'Saves athletes, weights & training days as default',
                style: const TextStyle(fontSize: 12),
              ),
              value: _autoImportEnabled,
              activeColor: Colors.green,
              onChanged: _selectedAthletes.isEmpty ? null : _saveAutoImportConfig,
            ),
          ),
          const SizedBox(height: 16),
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
