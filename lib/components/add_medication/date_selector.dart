import 'package:flutter/material.dart';
import 'package:med_track/utils/constants.dart';
import 'package:med_track/utils/helpers/medication_scheduling.dart';

class DateSelector extends StatelessWidget {
  final DateTime selectedDate;
  final VoidCallback onDateSelected;

  const DateSelector({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Start of use', style: AppTextStyles.bodyMedium),
        const SizedBox(height: AppSpacing.sm),
        InkWell(
          onTap: onDateSelected,
          child: InputDecorator(
            decoration: InputDecoration(
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(formatDateDdMmYyyy(selectedDate)),
          ),
        ),
      ],
    );
  }
}
