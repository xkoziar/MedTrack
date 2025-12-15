import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:med_track/database/model/entity.dart';

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
  final DoseStatus status;

  final DateTime createdAt = DateTime.now();

  DoseEvent({
    String? id,
    required this.userId,
    required this.medicationId,
    required this.scheduledAt,
    this.takenAt,
    required this.status,
  }) : id = id ?? const Uuid().v4(),
       assert(
         status != DoseStatus.taken || takenAt != null,
         'takenAt must be provided if status is taken',
       );

  factory DoseEvent.fromJson(Map<String, dynamic> json, {String? id}) {
    final event = _$DoseEventFromJson(json);
    return DoseEvent(
      id: id,
      userId: event.userId,
      medicationId: event.medicationId,
      scheduledAt: event.scheduledAt,
      takenAt: event.takenAt,
      status: event.status,
    );
  }

  Map<String, dynamic> toJson() => _$DoseEventToJson(this);
}

enum DoseStatus { taken, missed, skipped, pending }
