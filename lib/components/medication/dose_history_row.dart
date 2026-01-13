import 'package:flutter/material.dart';
import 'package:med_track/components/common/dose_status_chip.dart';
import 'package:med_track/database/model/dose_event.dart';
import 'package:med_track/utils/constants.dart';
import 'package:med_track/utils/helpers/medication_scheduling.dart';

class DoseHistoryRow extends StatelessWidget {
  final DoseEvent event;

  const DoseHistoryRow({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final label = relativeDayLabel(event.scheduledAt);
    final date = formatDateDdMmYyyy(event.scheduledAt);
    final time = formatTimeHm(event.takenAt ?? event.scheduledAt);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.bodyMediumSemiBold),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '$date • $time',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          DoseStatusChip(event: event),
        ],
      ),
    );
  }
}
