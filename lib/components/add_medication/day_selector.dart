import 'package:flutter/material.dart';
import 'package:med_track/utils/constants.dart';
import 'package:med_track/utils/helpers/medication_scheduling.dart';

class DaySelector extends StatelessWidget {
  final Set<int> selectedDays;
  final ValueChanged<int> onDayToggled;

  const DaySelector({
    super.key,
    required this.selectedDays,
    required this.onDayToggled,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Days of use *', style: AppTextStyles.bodyMedium),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (index) {
            final day = index + 1;
            final isSelected = selectedDays.contains(day);
            return GestureDetector(
              onTap: () => onDayToggled(day),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    weekdayNameShort(day),
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
