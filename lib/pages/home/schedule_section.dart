import 'package:flutter/material.dart';
import 'package:med_track/database/model/medication.dart';
import 'package:med_track/utils/constants.dart';
import 'package:med_track/components/common/app_card.dart';
import 'package:med_track/components/common/buttons/primary_button.dart';

import 'empty_state.dart';
import 'medication_item.dart';

class ScheduleSection extends StatelessWidget {
  final List<Map<String, dynamic>> todaySchedule;
  final Set<String> takenMedicationKeys;
  final List<Medication> medications;
  final int takenCount;
  final int totalToday;
  final Function(String, DateTime, bool) onToggleMedication;
  final VoidCallback onAddMedication;

  const ScheduleSection({
    super.key,
    required this.todaySchedule,
    required this.takenMedicationKeys,
    required this.medications,
    required this.takenCount,
    required this.totalToday,
    required this.onToggleMedication,
    required this.onAddMedication,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Today\'s Schedule', style: AppTextStyles.heading3),
            if (todaySchedule.isNotEmpty)
              Text(
                '${todaySchedule.length} dose${todaySchedule.length != 1 ? 's' : ''}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (todaySchedule.isEmpty)
          Column(
            children: [
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const EmptyState(),
                      const SizedBox(height: AppSpacing.xl),
                      SizedBox(
                        width: 200,
                        child: PrimaryGradientButton(
                          label: 'Add Medication',
                          onPressed: onAddMedication,
                          icon: const Icon(Icons.add),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (medications.isEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                AppCard(
                  color: AppColors.primary.withAlpha(13),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(38),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.tips_and_updates,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Track your medications easily',
                              style: AppTextStyles.bodyMediumSemiBold.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Add your medications to get reminders, track adherence, and never miss a dose.',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          )
        else
          Column(
            children: [
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: todaySchedule.length,
                itemBuilder: (context, index) {
                  final item = todaySchedule[index];
                  final medicationId = item['medicationId'] as String;
                  final medicationName =
                      item['name'] as String? ?? 'Unknown Medication';
                  final medicationDosage = item['dosage'] as String? ?? '';
                  final medicationTime = item['time'] as String? ?? '';
                  final scheduleTime = item['timeObject'] as DateTime;
                  final scheduleKey = '${medicationId}_$medicationTime';
                  final isTaken = takenMedicationKeys.contains(scheduleKey);

                  return MedicationItem(
                    name: '$medicationName ($medicationDosage)',
                    time: medicationTime,
                    isTaken: isTaken,
                    onTap: () =>
                        onToggleMedication(medicationId, scheduleTime, isTaken),
                  );
                },
              ),
              if (takenCount == totalToday && totalToday > 0) ...[
                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  color: AppColors.success.withAlpha(13),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.success.withAlpha(38),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.celebration,
                          color: AppColors.success,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Great job!',
                              style: AppTextStyles.bodyMediumSemiBold.copyWith(
                                color: AppColors.success,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'You\'ve completed all your medications for today. Keep up the excellent work!',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }
}
