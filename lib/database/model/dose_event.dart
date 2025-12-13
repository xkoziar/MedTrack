import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

part 'dose_event.g.dart';

@JsonSerializable()
class DoseEvent {
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

  factory DoseEvent.fromJson(Map<String, dynamic> json) =>
      _$DoseEventFromJson(json);

  Map<String, dynamic> toJson() => _$DoseEventToJson(this);
}

enum DoseStatus { taken, missed, skipped, pending }
