import 'package:flutter/material.dart';
import 'package:med_track/components/common/buttons/secondary_button.dart';
import '../../utils/constants.dart';

class DangerZoneCard extends StatelessWidget {
  final VoidCallback onDelete;

  const DangerZoneCard({super.key, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: AppColors.dangerBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Padding(
        padding: AppPadding.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning,
                  color: AppColors.danger,
                  size: AppSpacing.iconSm,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Danger Zone',
                  style: AppTextStyles.heading3.copyWith(
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Once you delete your account, there is no going back. Please be certain.',
              style: TextStyle(color: AppColors.textTertiary)
            ),
            const SizedBox(height: AppSpacing.md),
            SecondaryOutlineButton(
              label: 'Delete Account',
              onPressed: onDelete,
              danger: true,
              icon: const Icon(Icons.delete_forever),
            ),
          ],
        ),
      ),
    );
  }
}
