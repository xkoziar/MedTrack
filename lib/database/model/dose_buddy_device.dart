import 'package:json_annotation/json_annotation.dart';
import 'package:med_track/database/model/entity.dart';

part 'dose_buddy_device.g.dart';

@JsonSerializable()
class DoseBuddyDevice implements IEntity {
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String id;
  final String userId;
  final String displayName;
  final String bleDeviceId;
  final List<String> medicationIds;
  final List<String> manualIntervals;
  @JsonKey(defaultValue: false)
  final bool allowLateDispenseAfterMissedHour;
  final bool autoReconnectEnabled;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  DoseBuddyDevice({
    String? id,
    required this.userId,
    required this.displayName,
    required this.bleDeviceId,
    List<String>? medicationIds,
    List<String>? manualIntervals,
    this.allowLateDispenseAfterMissedHour = false,
    this.autoReconnectEnabled = true,
    this.isEnabled = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? userId,
       medicationIds = medicationIds ?? const [],
       manualIntervals = manualIntervals ?? const [],
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory DoseBuddyDevice.fromJson(Map<String, dynamic> json, {String? id}) {
    final device = _$DoseBuddyDeviceFromJson(json);
    return device.copyWith(id: id);
  }

  Map<String, dynamic> toJson() => _$DoseBuddyDeviceToJson(this);

  DoseBuddyDevice copyWith({
    String? id,
    String? userId,
    String? displayName,
    String? bleDeviceId,
    List<String>? medicationIds,
    List<String>? manualIntervals,
    bool? allowLateDispenseAfterMissedHour,
    bool? autoReconnectEnabled,
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DoseBuddyDevice(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      bleDeviceId: bleDeviceId ?? this.bleDeviceId,
      medicationIds: medicationIds ?? this.medicationIds,
      manualIntervals: manualIntervals ?? this.manualIntervals,
      allowLateDispenseAfterMissedHour:
          allowLateDispenseAfterMissedHour ??
          this.allowLateDispenseAfterMissedHour,
      autoReconnectEnabled: autoReconnectEnabled ?? this.autoReconnectEnabled,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
