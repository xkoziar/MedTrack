import 'package:json_annotation/json_annotation.dart';

part 'medication.g.dart';

@JsonSerializable()
class Medication {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final String dosage;
  final DateTime startDate;
  final DateTime? endDate;

  /// Easy pause toggle
  final bool isActive;

  /// ISO-8601 weekday numbers: 1=Mon ... 7=Sun
  final List<int> scheduleDays;

  /// Times in day as "HH:mm" (timezone-safe)
  final List<String> scheduleTimes;

  /// Optional metadata
  final DateTime createdAt;
  final DateTime updatedAt;

  Medication({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    required this.dosage,
    required this.startDate,
    this.endDate,
    required this.isActive,
    required this.scheduleDays,
    required this.scheduleTimes,
    required this.createdAt,
    required this.updatedAt,
  });


  factory Medication.fromJson(Map<String, dynamic> json) =>
      _$MedicationFromJson(json);

  Map<String, dynamic> toJson() => _$MedicationToJson(this);

  Medication copyWith({
    String? id,
    String? userId,
    String? name,
    String? description,
    String? dosage,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    List<int>? scheduleDays,
    List<String>? scheduleTimes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Medication(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: description ?? this.description,
      dosage: dosage ?? this.dosage,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      scheduleDays: scheduleDays ?? this.scheduleDays,
      scheduleTimes: scheduleTimes ?? this.scheduleTimes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
