import 'package:flutter/material.dart';
import 'package:med_track/utils/helpers/medication_scheduling.dart';
import 'package:med_track/database/model/dose_event.dart';

class DoseStatusChip extends StatelessWidget {
  final DoseEvent event;

  const DoseStatusChip({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final config = DoseStatusChipConfig.fromEvent(event);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, size: 15, color: config.foregroundColor),
          const SizedBox(width: 5),
          Text(
            config.label,
            style: TextStyle(
              color: config.foregroundColor,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class DoseStatusChipConfig {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;

  const DoseStatusChipConfig({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  factory DoseStatusChipConfig.fromEvent(DoseEvent event) {
    if (isTaken(event)) {
      return DoseStatusChipConfig(
        label: 'Taken ${formatTimeHm(event.takenAt!)}',
        icon: Icons.check_circle_rounded,
        backgroundColor: const Color(0xFFD4EDDA),
        foregroundColor: const Color(0xFF155724),
      );
    } else if (isMissed(event)) {
      return const DoseStatusChipConfig(
        label: 'Missed',
        icon: Icons.cancel_rounded,
        backgroundColor: Color(0xFFF8D7DA),
        foregroundColor: Color(0xFF721C24),
      );
    } else {
      return const DoseStatusChipConfig(
        label: 'Pending',
        icon: Icons.schedule_rounded,
        backgroundColor: Color(0xFFFFF3CD),
        foregroundColor: Color(0xFF856404),
      );
    }
  }
}
