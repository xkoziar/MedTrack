import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import '../../components/common/app_card.dart';

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
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AppCard(
          color: isTaken
              ? AppColors.success.withOpacity(0.05)
              : Colors.white,
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: isTaken
                      ? LinearGradient(
                          colors: [AppColors.success, AppColors.success.withOpacity(0.7)],
                        )
                      : null,
                  color: isTaken ? null : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: isTaken
                      ? null
                      : Border.all(color: Colors.grey[300]!, width: 1.5),
                ),
                child: Icon(
                  isTaken ? Icons.check_circle : Icons.medication_rounded,
                  color: isTaken ? Colors.white : Colors.grey[400],
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
                      style: AppTextStyles.bodyMediumSemiBold.copyWith(
                        decoration: isTaken ? TextDecoration.lineThrough : null,
                        color: isTaken ? AppColors.textSecondary : Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            time,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isTaken
                      ? AppColors.successBackground
                      : AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isTaken ? 'Taken' : 'Pending',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isTaken ? AppColors.success : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
