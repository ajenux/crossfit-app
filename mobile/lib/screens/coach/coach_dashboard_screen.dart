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
  List<dynamic> _availability = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await ApiService.getCoachAvailability(widget.coachId);
    setState(() { _availability = data; _loading = false; });
  }

  Future<void> _addSlot() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _AddAvailabilityDialog(),
    );
    if (result != null) {
      result['coachId'] = widget.coachId;
      await ApiService.addAvailability(result);
      _load();
    }
  }

  Future<void> _deleteSlot(int id) async {
    await ApiService.deleteAvailability(id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coach Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ApiService.clearToken();
              if (mounted) context.go('/login');
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addSlot,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _availability.isEmpty
              ? const Center(child: Text('No availability slots yet. Tap + to add one.'))
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
    );
  }
}

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
