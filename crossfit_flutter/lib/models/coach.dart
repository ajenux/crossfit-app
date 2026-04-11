class Coach {
  final int id;
  final String name;
  final String email;
  final int athleteCount;

  Coach({
    required this.id,
    required this.name,
    required this.email,
    required this.athleteCount,
  });

  factory Coach.fromJson(Map<String, dynamic> json) {
    return Coach(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      athleteCount: json['athleteCount'] as int,
    );
  }
}