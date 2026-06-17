import 'dart:convert';

import 'package:med_track/utils/constants.dart';

/// Encodes/decodes the data embedded in an account-sharing QR code.
///
/// Wire format: `medtrack-account-share:<base64Url(json)>` where the JSON is
/// `{"v":1,"uid":...,"name":...,"email":...}`. The patient (account owner)
/// encodes their own identity; the caregiver decodes it after scanning.
class AccountSharePayload {
  static const _version = 1;

  final String userId;
  final String name;
  final String email;

  const AccountSharePayload({
    required this.userId,
    required this.name,
    required this.email,
  });

  String encode() {
    final json = jsonEncode({
      'v': _version,
      'uid': userId,
      'name': name,
      'email': email,
    });
    final encoded = base64Url.encode(utf8.encode(json));
    return '${AccountShareConstants.qrPrefix}:$encoded';
  }

  /// Returns `null` when [raw] is not a valid MedTrack account-share code.
  static AccountSharePayload? tryParse(String raw) {
    final prefix = '${AccountShareConstants.qrPrefix}:';
    if (!raw.startsWith(prefix)) return null;

    try {
      final encoded = raw.substring(prefix.length);
      final json = jsonDecode(utf8.decode(base64Url.decode(encoded)))
          as Map<String, dynamic>;

      final uid = json['uid'] as String?;
      if (uid == null || uid.isEmpty) return null;

      return AccountSharePayload(
        userId: uid,
        name: (json['name'] as String?) ?? '',
        email: (json['email'] as String?) ?? '',
      );
    } catch (_) {
      return null;
    }
  }
}
