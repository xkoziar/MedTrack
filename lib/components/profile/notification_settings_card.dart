import 'package:flutter/material.dart';

import 'package:med_track/database/model/app_user.dart';
import 'package:med_track/utils/constants.dart';
import 'package:med_track/components/common/app_card.dart';

class NotificationSettingsCard extends StatelessWidget {
  final AppUser user;
  final ValueChanged<bool> onToggle;
  final ValueChanged<int> onReminderChanged;

  const NotificationSettingsCard({
    super.key,
    required this.user,
    required this.onToggle,
    required this.onReminderChanged,
  });

  static const reminderOptions = [0, 5, 10, 15, 30, 60];

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Notification Settings', style: AppTextStyles.heading3),
          const SizedBox(height: AppSpacing.sm),
          Material(
            color: Colors.transparent,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable Notifications'),
              subtitle: const Text('Receive reminders for medication doses'),
              value: user.notificationsEnabled,
              activeThumbColor: AppColors.primary,
              onChanged: onToggle,
            ),
          ),
          if (user.notificationsEnabled) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Text('Remind me'),
                const SizedBox(width: AppSpacing.sm),
                DropdownButton<int>(
                  value: user.reminderMinutes,
                  items: reminderOptions.map((mins) {
                    return DropdownMenuItem(
                      value: mins,
                      child: Text(
                        mins == 0 ? 'At dose time' : '$mins min before',
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) onReminderChanged(value);
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
