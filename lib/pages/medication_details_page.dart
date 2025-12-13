import 'package:flutter/material.dart';
import 'package:med_track/components/common/active_chip.dart';
import 'package:med_track/components/common/gradient_header.dart';
import 'package:med_track/components/nfc_card.dart';
import 'package:med_track/components/common/buttons/primary_button.dart';
import 'package:med_track/components/common/buttons/secondary_button.dart';
import 'package:med_track/components/medication/dose_history_card.dart';
import 'package:med_track/components/medication/medication_info_card.dart';
import 'package:med_track/database/model/dose_event.dart';
import 'package:med_track/database/model/medication.dart';
import 'package:med_track/utils/constants.dart';

import '../utils/helpers/medication_scheduling.dart';

class MedicationDetailPage extends StatelessWidget {
  final Medication medication;
  final List<DoseEvent> recentEvents;
  final String? nfcTagId;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onPairNfc;

  const MedicationDetailPage({
    super.key,
    required this.medication,
    required this.recentEvents,
    this.nfcTagId,
    this.onEdit,
    this.onDelete,
    this.onPairNfc,
  });

  @override
  Widget build(BuildContext context) {
    final sortedEvents = [...recentEvents]
      ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

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
                  NfcPairCard(nfcTagId: nfcTagId, onPair: onPairNfc),
                  const SizedBox(height: AppSpacing.xl),
                  DoseHistoryCard(events: sortedEvents),
                  const SizedBox(height: AppSpacing.xxl),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PrimaryGradientButton(
                        label: 'Edit',
                        onPressed: onEdit ?? () {},
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SecondaryOutlineButton(
                        label: 'Delete',
                        danger: true,
                        onPressed: () async {
                          final name = medication.name;
                          await _showDeleteDialog(context, name);
                          onDelete?.call();
                        },
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

  static Future<void> _showDeleteDialog(
    BuildContext context,
    String name,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete medication?'),
        content: Text('This will remove "$name" and its schedule.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.dangerBackground,
              foregroundColor: AppColors.danger,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('TODO: Delete confirmed')));
    }
  }
}
