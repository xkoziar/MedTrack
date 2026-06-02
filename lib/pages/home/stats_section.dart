import 'package:flutter/material.dart';
import 'package:med_track/utils/constants.dart';

import 'quick_stats_card.dart';

class StatsSection extends StatelessWidget {
  final int takenCount;
  final int totalToday;
  final int activeMedicationsCount;
  final int totalMedications;

  const StatsSection({
    super.key,
    required this.takenCount,
    required this.totalToday,
    required this.activeMedicationsCount,
    required this.totalMedications,
  });

  double _adherenceRate(int taken, int total) {
    if (total == 0) return 0.0;
    return (taken / total * 100).clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: QuickStatsCard(
            title: 'Today\'s Doses',
            value: '$takenCount/$totalToday',
            icon: Icons.schedule,
            color: AppColors.primary,
            subtitle: totalToday > 0
                ? '${_adherenceRate(takenCount, totalToday).toStringAsFixed(0)}% completed'
                : 'No doses scheduled',
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: QuickStatsCard(
            title: 'Active Meds',
            value: '$activeMedicationsCount',
            icon: Icons.medication,
            color: AppColors.success,
            subtitle: totalMedications == 0
                ? 'Start tracking'
                : '$totalMedications total',
          ),
        ),
      ],
    );
  }
}
