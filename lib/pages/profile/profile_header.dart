import 'package:flutter/material.dart';
import '../../database/model/user.dart';
import '../../utils/constants.dart';

class ProfileHeader extends StatelessWidget {
  final AppUser user;

  const ProfileHeader({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: AppSpacing.avatarRadius,
            backgroundColor: AppColors.primary,
            child: Text(
              user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
              style: AppTextStyles.avatarLetter,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(user.name, style: AppTextStyles.heading2),
          const SizedBox(height: AppSpacing.xs),
          Text(
            user.email,
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
