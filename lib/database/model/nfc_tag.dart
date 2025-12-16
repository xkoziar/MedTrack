import 'package:json_annotation/json_annotation.dart';
import 'package:med_track/database/model/entity.dart';
import 'package:uuid/uuid.dart';

part 'nfc_tag.g.dart';

@JsonSerializable()
class NfcTag implements IEntity {
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String id;
  final String userId;
  final String tagId; // The actual NFC chip ID (e.g., '04:A2:7F:19:CC:2B:80')
  final String name; // User-friendly name for the chip
  final List<String> medicationIds; // List of medication IDs assigned to this chip
  final DateTime createdAt;
  final DateTime updatedAt;

  NfcTag({
    String? id,
    required this.userId,
    required this.tagId,
    required this.name,
    required this.medicationIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory NfcTag.fromJson(Map<String, dynamic> json, {String? id}) {
    final tag = _$NfcTagFromJson(json);
    return tag.copyWith(id: id);
  }

  Map<String, dynamic> toJson() => _$NfcTagToJson(this);

  NfcTag copyWith({
    String? id,
    String? userId,
    String? tagId,
    String? name,
    List<String>? medicationIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NfcTag(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      tagId: tagId ?? this.tagId,
      name: name ?? this.name,
      medicationIds: medicationIds ?? this.medicationIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
