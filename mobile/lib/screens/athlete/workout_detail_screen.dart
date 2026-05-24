import 'package:flutter/material.dart';
import '../../services/workout_service.dart';

class WorkoutDetailScreen extends StatefulWidget {
  final Map<String, dynamic> workout;

  const WorkoutDetailScreen({super.key, required this.workout});

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  late Map<String, dynamic> _workout;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _workout = Map<String, dynamic>.from(widget.workout);
  }

  Future<void> _toggle() async {
    final newValue = !(_workout['completed'] == true);
    setState(() => _saving = true);
    final result = await WorkoutService.updateCompletion(_workout['id'] as int, newValue);
    if (!mounted) return;
    if (result.isSuccess) {
      setState(() {
        _workout = {..._workout, 'completed': newValue};
        _saving = false;
      });
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update status')),
      );
    }
  }

  String _formatType(String type) {
    return switch (type) {
      'FOR_TIME' => 'For Time',
      'AMRAP' => 'AMRAP',
      'EMOM' => 'EMOM',
      _ => type,
    };
  }

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = _workout['completed'] == true;
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_workout);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => Navigator.of(context).pop(_workout)),
          title: Text(_workout['name'] as String),
          backgroundColor: isCompleted
              ? Colors.green.shade50
              : colorScheme.surfaceContainerHighest,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusBanner(isCompleted: isCompleted),
              const SizedBox(height: 24),
              _InfoRow(icon: Icons.fitness_center, label: 'Type', value: _formatType(_workout['type'] as String)),
              const SizedBox(height: 12),
              _InfoRow(
                icon: Icons.calendar_today,
                label: 'Scheduled',
                value: _formatDate(_workout['scheduledDate'] as String),
              ),
              const SizedBox(height: 12),
              _InfoRow(
                icon: Icons.person,
                label: 'Coach',
                value: _workout['coachName'] as String,
              ),
              const Divider(height: 40),
              const Text(
                'Description',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if ((_workout['description'] as String?)?.isNotEmpty == true)
                _SectionedDescription(description: _workout['description'] as String)
              else
                const Text(
                  'No description provided.',
                  style: TextStyle(color: Colors.grey),
                ),
              const SizedBox(height: 80),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: FilledButton.icon(
              onPressed: _saving ? null : _toggle,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(isCompleted ? Icons.undo : Icons.check_circle_outline),
              label: Text(isCompleted ? 'Mark as pending' : 'Mark as completed'),
              style: FilledButton.styleFrom(
                backgroundColor: isCompleted ? Colors.grey : Colors.green,
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final bool isCompleted;
  const _StatusBanner({required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.green.shade100 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.pending_outlined,
            color: isCompleted ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 12),
          Text(
            isCompleted ? 'Completed' : 'Pending',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isCompleted ? Colors.green.shade800 : Colors.orange.shade800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionedDescription extends StatelessWidget {
  final String description;
  const _SectionedDescription({required this.description});

  static const _sections = {
    '[WARMUP]': ('Entrada en calor', Color(0xFF00796B), Color(0xFFE0F2F1)),
    '[FUERZA]': ('Fuerza', Color(0xFFE65100), Color(0xFFFFF3E0)),
    '[WOD]': ('WOD', Color(0xFFF57F17), Color(0xFFFFFDE7)),
  };

  static final _wodPattern = RegExp(
    r'(amrap|emom|for time|rxt|a completar|partner wod|\d+x.*amrap)',
    caseSensitive: false,
  );

  @override
  Widget build(BuildContext context) {
    final marked = description.contains('[WARMUP]') ||
        description.contains('[FUERZA]') ||
        description.contains('[WOD]');
    final lines = (marked ? description : _injectMarkers(description)).split('\n');

    final widgets = <Widget>[];
    String current = '';
    String? currentKey;

    for (final line in lines) {
      final trimmed = line.trim();
      if (_sections.containsKey(trimmed)) {
        if (currentKey != null && current.trim().isNotEmpty) {
          widgets.add(_SectionBlock(sectionKey: currentKey, content: current.trim(), sections: _sections));
          widgets.add(const SizedBox(height: 12));
        }
        currentKey = trimmed;
        current = '';
      } else {
        current += '$trimmed\n';
      }
    }
    if (currentKey != null && current.trim().isNotEmpty) {
      widgets.add(_SectionBlock(sectionKey: currentKey, content: current.trim(), sections: _sections));
    }

    if (widgets.isEmpty) {
      return Text(description, style: const TextStyle(fontSize: 15, height: 1.6));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }

  String _injectMarkers(String raw) {
    final lines = raw.split('\n');
    final result = StringBuffer('[WARMUP]\n');
    bool fuerzaFound = false;
    bool wodFound = false;
    for (final line in lines) {
      final lower = line.trim().toLowerCase();
      if (!fuerzaFound && !wodFound && lower == 'fuerza') {
        fuerzaFound = true;
        result.write('[FUERZA]\n');
        continue;
      }
      if (!wodFound && _wodPattern.hasMatch(lower)) {
        wodFound = true;
        result.write('[WOD]\n');
      }
      result.write('${line.trim()}\n');
    }
    return result.toString();
  }
}

class _SectionBlock extends StatelessWidget {
  final String sectionKey;
  final String content;
  final Map<String, (String, Color, Color)> sections;
  const _SectionBlock({required this.sectionKey, required this.content, required this.sections});

  @override
  Widget build(BuildContext context) {
    final (label, headerColor, bgColor) = sections[sectionKey]!;
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Text(label,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(content, style: const TextStyle(fontSize: 15, height: 1.6)),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
        Expanded(child: Text(value)),
      ],
    );
  }
}