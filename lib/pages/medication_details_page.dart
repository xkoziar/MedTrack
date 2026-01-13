import 'package:flutter/material.dart';
import 'package:med_track/components/common/active_chip.dart';
import 'package:med_track/components/common/gradient_header.dart';
import 'package:med_track/components/common/buttons/primary_button.dart';
import 'package:med_track/components/common/buttons/secondary_button.dart';
import 'package:med_track/components/medication/dose_history_card.dart';
import 'package:med_track/components/medication/medication_info_card.dart';
import 'package:med_track/database/model/dose_event.dart';
import 'package:med_track/database/model/medication.dart';
import 'package:med_track/pages/add_medication_page.dart';
import 'package:med_track/utils/constants.dart';
import 'package:med_track/utils/handling_stream_builder.dart';

import 'package:med_track/database/ioc/ioc_container.dart';
import 'package:med_track/database/service/dose_event/dose_event_database_service.dart';
import 'package:med_track/database/service/medication_database_service.dart';
import 'package:med_track/utils/helpers/medication_scheduling.dart';
import 'package:med_track/utils/snackbar_utils.dart';

class MedicationDetailPage extends StatelessWidget {
  final Medication medication;
  final _medicationService = get<MedicationDatabaseService>();
  final _doseEventService = get<DoseEventDatabaseService>();

  MedicationDetailPage({
    super.key,
    required this.medication,
  });

  Future<void> _handleDelete(BuildContext context) async {
    final confirmed = await _showDeleteDialog(context, medication.name);
    if (!confirmed) return;

    try {
      await _medicationService.delete(medication.id);

      if (!context.mounted) return;

      Navigator.of(context).pop();

      showSnackBar(context, 'Medication "${medication.name}" deleted.');
    } catch (e) {
      if (!context.mounted) return;
      showSnackBar(context, 'Error deleting medication: $e');
    }
  }

  void _handleEdit(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => AddMedicationPage(medication: medication),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nextDose = computeNextScheduled(
      now: DateTime.now(),
      scheduleDays: medication.scheduleDays,
      scheduleTimes: medication.scheduleTimes,
      endDate: medication.endDate,
      isActive: medication.isActive,
    );

    final subtitle = nextDose == null
        ? 'No upcoming doses'
        : 'Next: ${formatDateDdMmYyyy(nextDose)} • ${formatTimeHm(nextDose)}';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          GradientSliverHeader(
            title: medication.name,
            subtitle: subtitle,
            onBack: () => Navigator.of(context).maybePop(),
            trailing: ActiveChip(isActive: medication.isActive),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: AppPadding.page,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MedicationInfoCard(medication: medication),
                  const SizedBox(height: AppSpacing.xl),
                  HandlingStreamBuilder<List<DoseEvent>>(
                    stream: _doseEventService
                        .observeMedicationEventsTodayAndEarlier(
                          medication.id,
                        ),
                    builder: (events) {
                      final eventsWithVirtual = _addVirtualMissedDoses(events, medication);
                      return DoseHistoryCard(events: eventsWithVirtual);
                    },
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PrimaryGradientButton(
                        label: 'Edit',
                        onPressed: () => _handleEdit(context),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SecondaryOutlineButton(
                        label: 'Delete',
                        danger: true,
                        onPressed: () => _handleDelete(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<DoseEvent> _addVirtualMissedDoses(
    List<DoseEvent> existingEvents,
    Medication med,
  ) {
    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final sevenDaysAgo = DateTime(now.year, now.month, now.day).subtract(const Duration(days: MedicationConstants.scheduleLookAheadDays));

    final recentExistingEvents = existingEvents
        .where((e) => e.scheduledAt.isAfter(sevenDaysAgo))
        .toList();

    final existingScheduledTimes = <String>{};
    for (final event in recentExistingEvents) {
      existingScheduledTimes.add(_timeKey(event.scheduledAt));
    }

    final virtualEvents = <DoseEvent>[];
    final medStart = DateTime(med.startDate.year, med.startDate.month, med.startDate.day);
    final startDate = medStart.isAfter(sevenDaysAgo) ? medStart : sevenDaysAgo;

    for (var date = startDate; date.isBefore(endOfToday); date = date.add(const Duration(days: 1))) {
      if (!med.scheduleDays.contains(date.weekday)) continue;

      if (med.endDate != null) {
        final medEnd = DateTime(med.endDate!.year, med.endDate!.month, med.endDate!.day);
        if (date.isAfter(medEnd)) break;
      }

      for (final timeStr in med.scheduleTimes) {
        final parts = timeStr.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final scheduledTime = DateTime(date.year, date.month, date.day, hour, minute);

        if (scheduledTime.isAfter(now.subtract(const Duration(minutes: MedicationConstants.doseLateThresholdMinutes)))) continue;

        if (!existingScheduledTimes.contains(_timeKey(scheduledTime))) {
          virtualEvents.add(DoseEvent(
            userId: med.userId,
            medicationId: med.id,
            scheduledAt: scheduledTime,
            takenAt: null,
          ));
        }
      }
    }

    final allEvents = [...recentExistingEvents, ...virtualEvents];
    allEvents.sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

    return allEvents.take(10).toList();
  }

  String _timeKey(DateTime dt) => '${dt.year}-${dt.month}-${dt.day}-${dt.hour}-${dt.minute}';

  Future<bool> _showDeleteDialog(BuildContext context, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete medication?'),
        content: Text('This will remove "$name" and its schedule'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    return ok == true;
  }
}
