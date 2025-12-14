import 'package:flutter/material.dart';
import 'package:med_track/components/common/app_card.dart';
import '../../database/model/app_user.dart';
import '../../utils/constants.dart';

class NotificationSettingsCard extends StatelessWidget {
  final AppUser user;
  final ValueChanged<bool> onToggle;

  const NotificationSettingsCard({
    super.key,
    required this.user,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
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
    );
  }
}
