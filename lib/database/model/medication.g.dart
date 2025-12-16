// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'medication.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Medication _$MedicationFromJson(Map<String, dynamic> json) => Medication(
  userId: json['userId'] as String,
  name: json['name'] as String,
  description: json['description'] as String?,
  dosage: json['dosage'] as String,
  startDate: DateTime.parse(json['startDate'] as String),
  endDate: json['endDate'] == null
      ? null
      : DateTime.parse(json['endDate'] as String),
  isActive: json['isActive'] as bool,
  scheduleDays: (json['scheduleDays'] as List<dynamic>)
      .map((e) => (e as num).toInt())
      .toList(),
  scheduleTimes: (json['scheduleTimes'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  nfcTagId: json['nfcTagId'] as String?,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$MedicationToJson(Medication instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'name': instance.name,
      'description': instance.description,
      'dosage': instance.dosage,
      'startDate': instance.startDate.toIso8601String(),
      'endDate': instance.endDate?.toIso8601String(),
      'isActive': instance.isActive,
      'scheduleDays': instance.scheduleDays,
      'scheduleTimes': instance.scheduleTimes,
      'nfcTagId': instance.nfcTagId,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
