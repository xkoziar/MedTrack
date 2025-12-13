import 'package:flutter/material.dart';
import 'package:med_track/components/common/app_card.dart';
import 'package:med_track/utils/helpers/medication_scheduling.dart';

import '../../database/model/medication.dart';
import '../../utils/constants.dart';

class MedicationShortInfoCard extends StatelessWidget {
  final Medication medication;
  final VoidCallback onTap;

  const MedicationShortInfoCard({
    super.key,
    required this.medication,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheduleSummary = formatSchedule(
      medication.scheduleDays,
      medication.scheduleTimes,
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${medication.name} ${medication.dosage}',
              style: AppTextStyles.heading3,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              scheduleSummary,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '→ Show detail',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
