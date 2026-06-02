import 'package:json_annotation/json_annotation.dart';
import 'package:med_track/database/model/entity.dart';
import 'package:uuid/uuid.dart';

part 'dose_buddy_event.g.dart';

@JsonSerializable()
class DoseBuddyEvent implements IEntity {
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String id;
  final String userId;
  final String deviceId;
  final DateTime scheduledAt;
  final DateTime confirmedAt;
  final List<String> medicationIds;
  final String feedbackType;
  final DateTime createdAt;
  final DateTime updatedAt;

  DoseBuddyEvent({
    String? id,
    required this.userId,
    required this.deviceId,
    required this.scheduledAt,
    required this.confirmedAt,
    List<String>? medicationIds,
    required this.feedbackType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       medicationIds = medicationIds ?? const [],
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory DoseBuddyEvent.fromJson(Map<String, dynamic> json, {String? id}) {
    final event = _$DoseBuddyEventFromJson(json);
    return event.copyWith(id: id);
  }

  Map<String, dynamic> toJson() => _$DoseBuddyEventToJson(this);

  DoseBuddyEvent copyWith({
    String? id,
    String? userId,
    String? deviceId,
    DateTime? scheduledAt,
    DateTime? confirmedAt,
    List<String>? medicationIds,
    String? feedbackType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DoseBuddyEvent(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      medicationIds: medicationIds ?? this.medicationIds,
      feedbackType: feedbackType ?? this.feedbackType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
