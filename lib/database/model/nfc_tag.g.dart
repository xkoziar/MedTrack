// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nfc_tag.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NfcTag _$NfcTagFromJson(Map<String, dynamic> json) => NfcTag(
  userId: json['userId'] as String,
  tagId: json['tagId'] as String,
  name: json['name'] as String,
  medicationIds: (json['medicationIds'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$NfcTagToJson(NfcTag instance) => <String, dynamic>{
  'userId': instance.userId,
  'tagId': instance.tagId,
  'name': instance.name,
  'medicationIds': instance.medicationIds,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};
