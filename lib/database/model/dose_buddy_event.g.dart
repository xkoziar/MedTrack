// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dose_buddy_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DoseBuddyEvent _$DoseBuddyEventFromJson(Map<String, dynamic> json) =>
    DoseBuddyEvent(
      userId: json['userId'] as String,
      deviceId: json['deviceId'] as String,
      scheduledAt: DateTime.parse(json['scheduledAt'] as String),
      confirmedAt: DateTime.parse(json['confirmedAt'] as String),
      medicationIds: (json['medicationIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      feedbackType: json['feedbackType'] as String,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$DoseBuddyEventToJson(DoseBuddyEvent instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'deviceId': instance.deviceId,
      'scheduledAt': instance.scheduledAt.toIso8601String(),
      'confirmedAt': instance.confirmedAt.toIso8601String(),
      'medicationIds': instance.medicationIds,
      'feedbackType': instance.feedbackType,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
