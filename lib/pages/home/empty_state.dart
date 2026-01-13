import 'package:flutter/material.dart';
import 'package:med_track/utils/constants.dart';

class EmptyState extends StatelessWidget {
  final String? title;
  final String? subtitle;

  const EmptyState({super.key, this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.medical_services_outlined,
              size: 60,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            title ?? 'No medications scheduled',
            style: AppTextStyles.heading3.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              subtitle ?? 'Add your first medication to get started',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
