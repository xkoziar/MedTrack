import 'package:flutter/material.dart';

import '../../utils/constants.dart';
import '../common/app_card.dart';

class UserInfoCard extends StatelessWidget {
  final String name;
  final String email;

  const UserInfoCard({super.key, required this.name, required this.email});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      alignment: Alignment.bottomLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: AppTextStyles.heading3),
          const SizedBox(height: AppSpacing.sm),
          Text(
            email,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
