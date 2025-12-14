import 'package:flutter/material.dart';
import 'package:med_track/utils/constants.dart';

class TimeSelector extends StatelessWidget {
  final List<TimeOfDay> selectedTimes;
  final Function(int) onTimeSelected;
  final VoidCallback onAddTime;
  final Function(int) onRemoveTime;

  const TimeSelector({
    super.key,
    required this.selectedTimes,
    required this.onTimeSelected,
    required this.onAddTime,
    required this.onRemoveTime,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Times of use *', style: AppTextStyles.bodyMedium),
        const SizedBox(height: AppSpacing.sm),
        ...selectedTimes.asMap().entries.map((entry) {
          int idx = entry.key;
          TimeOfDay time = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => onTimeSelected(idx),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(time.format(context)),
                    ),
                  ),
                ),
                if (selectedTimes.length > 1)
                  IconButton(
                    icon: Icon(Icons.remove_circle_outline,
                        color: AppColors.danger),
                    onPressed: () => onRemoveTime(idx),
                  ),
              ],
            ),
          );
        }),
        const SizedBox(height: AppSpacing.xs),
        OutlinedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Add Time'),
          onPressed: onAddTime,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
          ),
        ),
      ],
    );
  }
}
