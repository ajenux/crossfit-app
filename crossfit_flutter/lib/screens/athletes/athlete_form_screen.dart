import 'package:flutter/material.dart';
import '../../models/athlete.dart';
import '../../models/coach.dart';
import '../../services/athlete_service.dart';
import '../../services/coach_service.dart';

class AthleteFormScreen extends StatefulWidget {
  final Athlete? athlete;

  const AthleteFormScreen({super.key, this.athlete});

  @override
  State<AthleteFormScreen> createState() => _AthleteFormScreenState();
}

class _AthleteFormScreenState extends State<AthleteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  List<Coach> _coaches = [];
  int? _selectedCoachId;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.athlete?.name ?? '');
    _emailController = TextEditingController(text: widget.athlete?.email ?? '');
    _selectedCoachId = widget.athlete?.coachId;
    _loadCoaches();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadCoaches() async {
    final coaches = await CoachService.findAll();
    setState(() => _coaches = coaches);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCoachId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a coach')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      if (widget.athlete == null) {
        await AthleteService.create(
          _nameController.text.trim(),
          _emailController.text.trim(),
          _selectedCoachId!,
        );
      } else {
        await AthleteService.update(
          widget.athlete!.id,
          _nameController.text.trim(),
          _emailController.text.trim(),
          _selectedCoachId!,
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
    final isEdit = widget.athlete != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Athlete' : 'New Athlete')),
      body: Padding(
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
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
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