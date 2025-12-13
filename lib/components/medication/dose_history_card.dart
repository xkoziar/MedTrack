import 'package:flutter/material.dart';
import '../common/app_card.dart';
import '../../database/model/dose_event.dart';
import '../../utils/constants.dart';
import 'dose_history_row.dart';

class DoseHistoryCard extends StatelessWidget {
  final List<DoseEvent> events;

  const DoseHistoryCard({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Dose history', style: AppTextStyles.heading3),
          const SizedBox(height: AppSpacing.md),
          if (events.isEmpty)
            Text(
              'No history yet.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            Column(
              children: events
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: DoseHistoryRow(event: e),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}
