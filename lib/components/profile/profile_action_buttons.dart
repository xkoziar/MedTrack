import 'package:flutter/material.dart';
import 'package:med_track/components/common/buttons/primary_button.dart';
import 'package:med_track/components/common/buttons/secondary_button.dart';
import 'package:med_track/utils/constants.dart';

class ProfileActionButtons extends StatelessWidget {
  final VoidCallback onChangePassword;
  final VoidCallback onManageNfcTags;
  final VoidCallback onLogout;

  const ProfileActionButtons({
    super.key,
    required this.onChangePassword,
    required this.onManageNfcTags,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SecondaryOutlineButton(label: 'Change Password', onPressed: onChangePassword, icon: const Icon(Icons.lock)),
        const SizedBox(height: AppSpacing.md),
        SecondaryOutlineButton(label: 'Manage NFC Tags', onPressed: onManageNfcTags, icon: const Icon(Icons.nfc)),
        const SizedBox(height: AppSpacing.md),
        PrimaryGradientButton(label: 'Logout', onPressed: onLogout, icon: const Icon(Icons.logout)),
      ],
    );
  }
}
