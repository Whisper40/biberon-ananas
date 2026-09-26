enum BabyEventType {
  breastfeeding('Allaitement'),
  bottle('Biberon'),
  pumping('Tirage de lait'),
  weight('Poids'),
  height('Taille');

  const BabyEventType(this.label);

  final String label;

  static BabyEventType fromJson(Object? value) =>
      BabyEventType.values.firstWhere(
        (type) => type.name == value,
        orElse: () => BabyEventType.breastfeeding,
      );
}

enum BreastSide {
  left('Gauche'),
  right('Droit'),
  both('Les deux');

  const BreastSide(this.label);

  final String label;

  static BreastSide? fromJson(Object? value) => value == null
      ? null
      : BreastSide.values.cast<BreastSide?>().firstWhere(
          (side) => side?.name == value,
          orElse: () => null,
        );
}

class BabyEvent {
  const BabyEvent({
    required this.id,
    required this.babyId,
    required this.type,
    required this.startedAt,
    required this.createdAt,
    this.durationSeconds,
    this.breastSide,
    this.amountMl,
    this.measurement,
  });

  final String id;
  final String babyId;
  final BabyEventType type;
  final DateTime startedAt;
  final DateTime createdAt;
  final int? durationSeconds;
  final BreastSide? breastSide;
  final int? amountMl;
  final double? measurement;

  Map<String, Object?> toJson() => {
    'id': id,
    'babyId': babyId,
    'type': type.name,
    'startedAt': startedAt.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'durationSeconds': durationSeconds,
    'breastSide': breastSide?.name,
    'amountMl': amountMl,
    'measurement': measurement,
  };

  factory BabyEvent.fromJson(Map<String, dynamic> json) => BabyEvent(
    id: json['id'] as String,
    babyId: json['babyId'] as String,
    type: BabyEventType.fromJson(json['type']),
    startedAt: DateTime.parse(json['startedAt'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
    durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
    breastSide: BreastSide.fromJson(json['breastSide']),
    amountMl: (json['amountMl'] as num?)?.toInt(),
    measurement: (json['measurement'] as num?)?.toDouble(),
  );
}
