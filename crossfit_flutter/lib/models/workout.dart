// ignore: constant_identifier_names
enum WorkoutType { AMRAP, FOR_TIME, EMOM, STRENGTH, ENDURANCE }

class Workout {
  final int id;
  final String name;
  final String description;
  final WorkoutType type;
  final String scheduledDate;
  final int athleteId;
  final String athleteName;
  final int coachId;
  final String coachName;

  Workout({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.scheduledDate,
    required this.athleteId,
    required this.athleteName,
    required this.coachId,
    required this.coachName,
  });

  factory Workout.fromJson(Map<String, dynamic> json) {
    return Workout(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String,
      type: WorkoutType.values.firstWhere(
        (e) => e.name == json['type'],
      ),
      scheduledDate: json['scheduledDate'] as String,
      athleteId: json['athleteId'] as int,
      athleteName: json['athleteName'] as String,
      coachId: json['coachId'] as int,
      coachName: json['coachName'] as String,
    );
  }
}
