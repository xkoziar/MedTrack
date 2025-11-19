import 'package:flutter/material.dart';
import '../../utils/constants.dart';

class MedicationItem extends StatelessWidget {
  final String name;
  final String time;
  final bool isTaken;
  final VoidCallback onTap;

  const MedicationItem({
    super.key,
    required this.name,
    required this.time,
    required this.isTaken,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Padding(
          padding: AppPadding.card,
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isTaken ? AppColors.primary.withValues(alpha: 0.1) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(AppSpacing.sm),
                ),
                child: Icon(
                  Icons.medication,
                  color: isTaken ? AppColors.primary : Colors.grey[400],
                  size: 28,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTextStyles.bodyMediumSemiBold,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isTaken ? Icons.check_circle : Icons.circle_outlined,
                color: isTaken ? AppColors.primary : Colors.grey[300],
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
