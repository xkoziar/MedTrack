import 'package:json_annotation/json_annotation.dart';
import 'package:med_track/database/model/entity.dart';

part 'app_user.g.dart';

@JsonSerializable()
class AppUser implements IEntity {
  @override
  final String? id;
  final String email;
  final String name;
  final bool notificationsEnabled;

  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    this.notificationsEnabled = true,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) =>
      _$AppUserFromJson(json);

  Map<String, dynamic> toJson() => _$AppUserToJson(this);

  AppUser copyWith({
    String? id,
    String? email,
    String? name,
    bool? notificationsEnabled,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }
}
