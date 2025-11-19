import 'package:flutter/material.dart';
import '../../database/model/user.dart';
import '../../utils/constants.dart';

class UserInfoCard extends StatelessWidget {
  final User user;

  const UserInfoCard({super.key, required this.user});

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
            Text('Account Information', style: AppTextStyles.heading3),
            const SizedBox(height: AppSpacing.lg),
            _InfoRow(icon: Icons.person, label: 'Username', value: user.name),
            const Divider(height: AppSpacing.xl),
            _InfoRow(icon: Icons.email, label: 'Email', value: user.email),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: AppSpacing.iconSm),
        const SizedBox(width: AppSpacing.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.captionSecondary),
            const SizedBox(height: 2),
            Text(value, style: AppTextStyles.bodyMediumSemiBold),
          ],
        ),
      ],
    );
  }
}
