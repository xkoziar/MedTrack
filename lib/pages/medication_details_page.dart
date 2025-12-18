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

import '../database/ioc/ioc_container.dart';
import '../database/service/dose_event/dose_event_database_service.dart';
import '../database/service/medication_database_service.dart';
import '../utils/helpers/medication_scheduling.dart';
import '../utils/snackbar_utils.dart';

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
                          limit: 7,
                        ),
                    builder: (events) => DoseHistoryCard(events: events),
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
