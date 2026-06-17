// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppUser _$AppUserFromJson(Map<String, dynamic> json) => AppUser(
  id: json['id'] as String?,
  email: json['email'] as String,
  name: json['name'] as String,
  notificationsEnabled: json['notificationsEnabled'] as bool? ?? false,
  reminderMinutes: (json['reminderMinutes'] as num?)?.toInt() ?? 15,
);

Map<String, dynamic> _$AppUserToJson(AppUser instance) => <String, dynamic>{
  'id': instance.id,
  'email': instance.email,
  'name': instance.name,
  'notificationsEnabled': instance.notificationsEnabled,
  'reminderMinutes': instance.reminderMinutes,
};
