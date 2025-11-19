import 'package:flutter/material.dart';
import '../../database/model/user.dart';
import '../../utils/constants.dart';

class NotificationSettingsCard extends StatelessWidget {
  final User user;
  final ValueChanged<bool> onToggle;

  const NotificationSettingsCard({
    super.key,
    required this.user,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Padding(
        padding: AppPadding.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Notification Settings', style: AppTextStyles.heading3),
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable Notifications'),
              subtitle: const Text('Receive reminders for medication doses'),
              value: user.notificationsEnabled,
              activeThumbColor: AppColors.primary,
              onChanged: onToggle,
            ),
          ],
        ),
      ),
    );
  }
}
