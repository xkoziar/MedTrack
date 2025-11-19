import 'package:flutter/material.dart';
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning,
                    color: AppColors.danger, size: AppSpacing.iconSm),
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
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_forever),
                label: const Text('Delete Account'),
                style: AppButtonStyles.dangerOutlinedButton,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
