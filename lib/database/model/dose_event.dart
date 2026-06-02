import 'package:json_annotation/json_annotation.dart';
import 'package:med_track/database/model/entity.dart';
import 'package:med_track/utils/constants.dart';
import 'package:uuid/uuid.dart';

part 'dose_event.g.dart';

@JsonSerializable()
class DoseEvent implements IEntity {
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String id;
  final String userId;
  final String medicationId;
  final DateTime scheduledAt;
  final DateTime? takenAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  DoseEvent({
    String? id,
    required this.userId,
    required this.medicationId,
    required this.scheduledAt,
    this.takenAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory DoseEvent.fromJson(Map<String, dynamic> json, {String? id}) {
    final doseEvent = _$DoseEventFromJson(json);
    return doseEvent.copyWith(id: id);
  }

  Map<String, dynamic> toJson() => _$DoseEventToJson(this);

  DoseEvent copyWith({
    String? id,
    String? userId,
    String? medicationId,
    DateTime? scheduledAt,
    DateTime? takenAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DoseEvent(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      medicationId: medicationId ?? this.medicationId,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      takenAt: takenAt ?? this.takenAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

bool isTaken(DoseEvent event) => event.takenAt != null;

bool isMissed(DoseEvent event, [DateTime? now]) {
  now ??= DateTime.now();
  return event.takenAt == null &&
         now.isAfter(event.scheduledAt.add(const Duration(minutes: MedicationConstants.doseLateThresholdMinutes)));
}

bool isUpcoming(DoseEvent event, [DateTime? now]) {
  now ??= DateTime.now();
  return event.takenAt == null &&
         now.isBefore(event.scheduledAt.add(const Duration(minutes: MedicationConstants.doseLateThresholdMinutes)));
}
