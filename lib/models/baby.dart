enum BabyGender {
  girl('Fille'),
  boy('Garçon');

  const BabyGender(this.label);

  final String label;

  static BabyGender fromJson(Object? value) => BabyGender.values.firstWhere(
    (gender) => gender.name == value,
    orElse: () => BabyGender.girl,
  );
}

class Baby {
  const Baby({
    required this.id,
    required this.name,
    required this.gender,
    required this.birthDate,
  });

  final String id;
  final String name;
  final BabyGender gender;
  final DateTime birthDate;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'gender': gender.name,
    'birthDate': birthDate.toIso8601String(),
  };

  factory Baby.fromJson(Map<String, dynamic> json) => Baby(
    id: json['id'] as String,
    name: json['name'] as String,
    gender: BabyGender.fromJson(json['gender']),
    birthDate: DateTime.parse(json['birthDate'] as String),
  );
}
