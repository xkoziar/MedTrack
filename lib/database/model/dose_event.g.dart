// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dose_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DoseEvent _$DoseEventFromJson(Map<String, dynamic> json) => DoseEvent(
  id: json['id'] as String,
  userId: json['userId'] as String,
  medicationId: json['medicationId'] as String,
  scheduledAt: DateTime.parse(json['scheduledAt'] as String),
  takenAt: json['takenAt'] == null
      ? null
      : DateTime.parse(json['takenAt'] as String),
  status: $enumDecode(_$DoseStatusEnumMap, json['status']),
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$DoseEventToJson(DoseEvent instance) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'medicationId': instance.medicationId,
  'scheduledAt': instance.scheduledAt.toIso8601String(),
  'takenAt': instance.takenAt?.toIso8601String(),
  'status': _$DoseStatusEnumMap[instance.status]!,
  'createdAt': instance.createdAt.toIso8601String(),
};

const _$DoseStatusEnumMap = {
  DoseStatus.taken: 'taken',
  DoseStatus.missed: 'missed',
  DoseStatus.skipped: 'skipped',
  DoseStatus.pending: 'pending',
};
