// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_link.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AccountLink _$AccountLinkFromJson(Map<String, dynamic> json) => AccountLink(
  patientUserId: json['patientUserId'] as String,
  patientName: json['patientName'] as String,
  patientEmail: json['patientEmail'] as String,
  caregiverUserId: json['caregiverUserId'] as String,
  caregiverName: json['caregiverName'] as String,
  caregiverEmail: json['caregiverEmail'] as String,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$AccountLinkToJson(AccountLink instance) =>
    <String, dynamic>{
      'patientUserId': instance.patientUserId,
      'patientName': instance.patientName,
      'patientEmail': instance.patientEmail,
      'caregiverUserId': instance.caregiverUserId,
      'caregiverName': instance.caregiverName,
      'caregiverEmail': instance.caregiverEmail,
      'createdAt': instance.createdAt.toIso8601String(),
    };
