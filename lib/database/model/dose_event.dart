import 'package:json_annotation/json_annotation.dart';

part 'dose_event.g.dart';

@JsonSerializable()
class DoseEvent {
  final String id;
  final String userId;
  final String medicationId;

  /// When it was planned (local schedule projected to a real datetime)
  final DateTime scheduledAt;

  /// When user actually took it (null if not taken)
  final DateTime? takenAt;

  /// taken / missed / skipped / snoozed
  final DoseStatus status;

  final DateTime createdAt;

  DoseEvent({
    required this.id,
    required this.userId,
    required this.medicationId,
    required this.scheduledAt,
    this.takenAt,
    required this.status,
    required this.createdAt,
  });

  factory DoseEvent.fromJson(Map<String, dynamic> json) =>
      _$DoseEventFromJson(json);

  Map<String, dynamic> toJson() => _$DoseEventToJson(this);
}

enum DoseStatus { taken, missed, skipped, pending }
