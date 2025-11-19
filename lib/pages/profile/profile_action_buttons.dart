import 'package:flutter/material.dart';
import '../../utils/constants.dart';

class ProfileActionButtons extends StatelessWidget {
  final VoidCallback onChangePassword;
  final VoidCallback onLogout;

  const ProfileActionButtons({
    super.key,
    required this.onChangePassword,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onChangePassword,
            icon: const Icon(Icons.lock),
            label: const Text('Change Password'),
            style: AppButtonStyles.primaryOutlinedButton,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
            style: AppButtonStyles.primaryButton,
          ),
        ),
      ],
    );
  }
}
