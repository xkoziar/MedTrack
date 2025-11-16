// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'medication.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Medication _$MedicationFromJson(Map<String, dynamic> json) => Medication(
  id: json['id'] as String,
  userId: json['userId'] as String,
  name: json['name'] as String,
  description: json['description'] as String? ?? '',
  dosage: json['dosage'] as String,
  scheduleTimes: Medication._timesFromJson(json['scheduleTimes'] as List),
  scheduleDays: (json['scheduleDays'] as List<dynamic>)
      .map((e) => (e as num).toInt())
      .toList(),
);

Map<String, dynamic> _$MedicationToJson(Medication instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'name': instance.name,
      'description': instance.description,
      'dosage': instance.dosage,
      'scheduleTimes': Medication._timesToJson(instance.scheduleTimes),
      'scheduleDays': instance.scheduleDays,
    };
