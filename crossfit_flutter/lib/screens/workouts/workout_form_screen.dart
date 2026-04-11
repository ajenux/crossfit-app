import 'package:flutter/material.dart';
import '../../models/athlete.dart';
import '../../models/coach.dart';
import '../../models/workout.dart';
import '../../services/athlete_service.dart';
import '../../services/coach_service.dart';
import '../../services/workout_service.dart';

class WorkoutFormScreen extends StatefulWidget {
  final Workout? workout;

  const WorkoutFormScreen({super.key, this.workout});

  @override
  State<WorkoutFormScreen> createState() => _WorkoutFormScreenState();
}

class _WorkoutFormScreenState extends State<WorkoutFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _dateController;

  List<Athlete> _athletes = [];
  List<Coach> _coaches = [];
  int? _selectedAthleteId;
  int? _selectedCoachId;
  String _selectedType = WorkoutType.AMRAP.name;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final w = widget.workout;
    _nameController = TextEditingController(text: w?.name ?? '');
    _descriptionController = TextEditingController(text: w?.description ?? '');
    _dateController = TextEditingController(text: w?.scheduledDate ?? '');
    _selectedAthleteId = w?.athleteId;
    _selectedCoachId = w?.coachId;
    _selectedType = w?.type.name ?? WorkoutType.AMRAP.name;
    _loadDropdowns();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _loadDropdowns() async {
    final results = await Future.wait([
      AthleteService.findAll(),
      CoachService.findAll(),
    ]);
    setState(() {
      _athletes = results[0] as List<Athlete>;
      _coaches = results[1] as List<Coach>;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      _dateController.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAthleteId == null || _selectedCoachId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select athlete and coach')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      if (widget.workout == null) {
        await WorkoutService.create(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          type: _selectedType,
          scheduledDate: _dateController.text.trim(),
          athleteId: _selectedAthleteId!,
          coachId: _selectedCoachId!,
        );
      } else {
        await WorkoutService.update(
          id: widget.workout!.id,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          type: _selectedType,
          scheduledDate: _dateController.text.trim(),
          athleteId: _selectedAthleteId!,
          coachId: _selectedCoachId!,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.workout != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Workout' : 'New Workout')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              // ignore: deprecated_member_use
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
                items: WorkoutType.values
                    .map((t) => DropdownMenuItem(value: t.name, child: Text(t.name)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedType = v!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dateController,
                decoration: const InputDecoration(
                  labelText: 'Scheduled Date',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: _pickDate,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              // ignore: deprecated_member_use
              DropdownButtonFormField<int>(
                value: _selectedAthleteId,
                decoration: const InputDecoration(
                  labelText: 'Athlete',
                  border: OutlineInputBorder(),
                ),
                items: _athletes
                    .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedAthleteId = v),
                hint: const Text('Select an athlete'),
              ),
              const SizedBox(height: 16),
              // ignore: deprecated_member_use
              DropdownButtonFormField<int>(
                value: _selectedCoachId,
                decoration: const InputDecoration(
                  labelText: 'Coach',
                  border: OutlineInputBorder(),
                ),
                items: _coaches
                    .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCoachId = v),
                hint: const Text('Select a coach'),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _save,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isEdit ? 'Update' : 'Create'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}