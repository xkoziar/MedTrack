import 'package:json_annotation/json_annotation.dart';
import 'package:med_track/database/model/entity.dart';
import 'package:uuid/uuid.dart';

part 'medication.g.dart';

@JsonSerializable()
class Medication implements IEntity {
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String id;
  final String userId;
  final String name;
  final String? description;
  final String dosage;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;
  final List<int> scheduleDays;
  final List<String> scheduleTimes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Medication({
    String? id,
    required this.userId,
    required this.name,
    this.description,
    required this.dosage,
    required this.startDate,
    this.endDate,
    required this.isActive,
    required this.scheduleDays,
    required this.scheduleTimes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now(),
       assert(
         scheduleDays.every((d) => d >= 1 && d <= 7),
         'scheduleDays must contain values between 1 and 7',
       ),
       assert(
         endDate == null || !endDate.isBefore(startDate),
         'endDate must be after startDate',
       );

  factory Medication.fromJson(Map<String, dynamic> json, {String? id}) {
    final medication = _$MedicationFromJson(json);
    // The 'id' from json is ignored, so we set it from the document ID.
    return medication.copyWith(id: id);
  }

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
