import 'package:flutter/material.dart';
import '../common/app_card.dart';
import '../common/app_key_value.dart';
import '../../database/model/medication.dart';
import '../../utils/helpers/medication_scheduling.dart';

class MedicationInfoCard extends StatelessWidget {
  final Medication medication;

  const MedicationInfoCard({super.key, required this.medication});

  @override
  Widget build(BuildContext context) {
    final schedule = formatSchedule(
      medication.scheduleDays,
      medication.scheduleTimes,
    );

    final rows = <(String, String)>[
      ('Dosage', medication.dosage),
      ('Schedule', schedule.isEmpty ? '—' : schedule),
      ('Start', formatDateDdMmYyyy(medication.startDate)),
      (
        'End',
        medication.endDate == null
            ? '—'
            : formatDateDdMmYyyy(medication.endDate!),
      ),
    ];

    if ((medication.description ?? '').trim().isNotEmpty) {
      rows.add(('Note', medication.description!.trim()));
    }

    return AppCard(
      child: AppKeyValueColumn(title: 'Medication info', rows: rows),
    );
  }
}
