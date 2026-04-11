class Athlete {
  final int id;
  final String name;
  final String email;
  final int? coachId;
  final String? coachName;

  Athlete({
    required this.id,
    required this.name,
    required this.email,
    this.coachId,
    this.coachName,
  });

  factory Athlete.fromJson(Map<String, dynamic> json) {
    return Athlete(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      coachId: json['coachId'] as int?,
      coachName: json['coachName'] as String?,
    );
  }
}
