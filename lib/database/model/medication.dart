import 'package:json_annotation/json_annotation.dart';

part 'medication.g.dart';

@JsonSerializable()
class Medication {
  final String id;
  final String userId;
  final String name;
  final String description;
  final String dosage;
  @JsonKey(fromJson: _timesFromJson, toJson: _timesToJson)
  final List<DateTime> scheduleTimes;
  final List<int> scheduleDays;

  const Medication({
    required this.id,
    required this.userId,
    required this.name,
    this.description = '',
    required this.dosage,
    required this.scheduleTimes,
    required this.scheduleDays,
  });

  factory Medication.fromJson(Map<String, dynamic> json) =>
      _$MedicationFromJson(json);

  Map<String, dynamic> toJson() => _$MedicationToJson(this);

  static List<DateTime> _timesFromJson(List<dynamic> times) {
    return times.map((t) => DateTime.parse(t as String)).toList();
  }

  static List<String> _timesToJson(List<DateTime> times) {
    return times.map((t) => t.toIso8601String()).toList();
  }

  Medication copyWith({
    String? id,
    String? userId,
    String? name,
    String? description,
    String? dosage,
    List<DateTime>? scheduleTimes,
    List<int>? scheduleDays,
  }) {
    return Medication(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: description ?? this.description,
      dosage: dosage ?? this.dosage,
      scheduleTimes: scheduleTimes ?? this.scheduleTimes,
      scheduleDays: scheduleDays ?? this.scheduleDays,
    );
  }
}
