import 'package:flutter/material.dart';
import 'package:med_track/database/model/medication.dart';
import 'package:med_track/utils/helpers/medication_scheduling.dart';
import '../common/dose_status_chip.dart';
import '../../database/model/dose_event.dart';
import '../../utils/constants.dart';

class HistoryDoseEventRow extends StatelessWidget {
  final DoseEvent event;
  final Medication? medication;

  const HistoryDoseEventRow({
    super.key,
    required this.event,
    required this.medication,
  });

  @override
  Widget build(BuildContext context) {
    final time = formatTimeHm(event.scheduledAt);
    final medicationName = medication?.name ?? 'Unknown Medication';
    final medicationDose = medication?.dosage ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$medicationName $medicationDose',
                  style: AppTextStyles.bodyMediumSemiBold,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: AppTextSizes.bodySmall,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          DoseStatusChip(status: event.status, takenAt: event.takenAt),
        ],
      ),
    );
  }
}
