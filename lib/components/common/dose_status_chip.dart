import 'package:flutter/material.dart';
import 'package:med_track/utils/helpers/medication_scheduling.dart';
import '../../database/model/dose_event.dart';

class DoseStatusChip extends StatelessWidget {
  final DoseStatus status;
  final DateTime? takenAt;

  const DoseStatusChip({
    super.key,
    required this.status,
    this.takenAt,
  });

  @override
  Widget build(BuildContext context) {
    final config = DoseStatusChipConfig.fromStatus(status, takenAt);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        config.label,
        style: TextStyle(
          color: config.foregroundColor,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class DoseStatusChipConfig {
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  const DoseStatusChipConfig({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  factory DoseStatusChipConfig.fromStatus(
    DoseStatus status,
    DateTime? takenAt,
  ) {
    switch (status) {
      case DoseStatus.taken:
        return DoseStatusChipConfig(
          label:
              takenAt == null ? 'Taken' : '✓ Taken ${formatTimeHm(takenAt)}',
          backgroundColor: Color(0xFFD4EDDA),
          foregroundColor: Color(0xFF155724),
        );
      case DoseStatus.missed:
        return const DoseStatusChipConfig(
          label: '✗ Missed',
          backgroundColor: Color(0xFFF8D7DA),
          foregroundColor: Color(0xFF721C24),
        );
      case DoseStatus.pending:
        return const DoseStatusChipConfig(
          label: '⏳ Pending',
          backgroundColor: Color(0xFFFFF3CD),
          foregroundColor: Color(0xFF856404),
        );
    }
  }
}
