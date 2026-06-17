// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dose_buddy_device.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DoseBuddyDevice _$DoseBuddyDeviceFromJson(Map<String, dynamic> json) =>
    DoseBuddyDevice(
      userId: json['userId'] as String,
      displayName: json['displayName'] as String,
      bleDeviceId: json['bleDeviceId'] as String,
      medicationIds: (json['medicationIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      manualIntervals: (json['manualIntervals'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      allowLateDispenseAfterMissedHour:
          json['allowLateDispenseAfterMissedHour'] as bool? ?? false,
      autoReconnectEnabled: json['autoReconnectEnabled'] as bool? ?? true,
      isEnabled: json['isEnabled'] as bool? ?? true,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$DoseBuddyDeviceToJson(
  DoseBuddyDevice instance,
) => <String, dynamic>{
  'userId': instance.userId,
  'displayName': instance.displayName,
  'bleDeviceId': instance.bleDeviceId,
  'medicationIds': instance.medicationIds,
  'manualIntervals': instance.manualIntervals,
  'allowLateDispenseAfterMissedHour': instance.allowLateDispenseAfterMissedHour,
  'autoReconnectEnabled': instance.autoReconnectEnabled,
  'isEnabled': instance.isEnabled,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};
