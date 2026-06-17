import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:med_track/components/common/active_chip.dart';
import 'package:med_track/components/common/adherence_rate_card.dart';
import 'package:med_track/components/common/app_card.dart';
import 'package:med_track/components/common/dose_status_chip.dart';
import 'package:med_track/components/common/gradient_header.dart';
import 'package:med_track/components/history/history_dose_event_row.dart';
import 'package:med_track/components/profile/user_stats_card.dart';
import 'package:med_track/database/ioc/ioc_container.dart';
import 'package:med_track/database/model/dose_event.dart';
import 'package:med_track/database/model/medication.dart';
import 'package:med_track/database/service/dose_event/dose_event_database_service.dart';
import 'package:med_track/database/service/medication_database_service.dart';
import 'package:med_track/pages/home/home_helpers.dart';
import 'package:med_track/utils/constants.dart';
import 'package:med_track/utils/handling_stream_builder.dart';
import 'package:med_track/utils/helpers/adherence_calculator.dart';
import 'package:med_track/utils/helpers/medication_scheduling.dart';

/// Read-only overview of a linked patient's medications, today's doses and
/// history, opened by a caregiver from [LinkedAccountsCard]. The caregiver
/// cannot edit anything here — all confirmation paths stay with the patient.
///
/// Data access relies on Firestore rules that allow a caregiver to read the
/// patient's `medications` / `dose_events` when an `account_links` doc exists.
class CaregiverPatientPage extends StatelessWidget {
  final String patientUserId;
  final String patientName;
  final String patientEmail;

  CaregiverPatientPage({
    super.key,
    required this.patientUserId,
    required this.patientName,
    required this.patientEmail,
  });

  final _medicationDbService = get<MedicationDatabaseService>();
  final _doseEventDbService = get<DoseEventDatabaseService>();

  @override
  Widget build(BuildContext context) {
    final title = patientName.trim().isNotEmpty ? patientName : patientEmail;

    return Scaffold(
      body: HandlingStreamBuilder<List<Medication>>(
        stream: _medicationDbService.observeUserMedications(patientUserId),
        builder: (medications) {
          final medicationMap = {for (final m in medications) m.id: m};

          return HandlingStreamBuilder<List<DoseEvent>>(
            stream: _doseEventDbService.observeUserDoseEvents(patientUserId),
            builder: (events) {
              return CustomScrollView(
                slivers: [
                  GradientSliverHeader(
                    title: title,
                    subtitle: 'Read-only overview',
                    onBack: () => Navigator.of(context).pop(),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: AppPadding.page,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _ReadOnlyBanner(email: patientEmail),
                          const SizedBox(height: AppSpacing.lg),
                          _AdherenceSummary(
                            events: events,
                            medications: medications,
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          _TodaySection(
                            medications: medications,
                            events: events,
                            patientUserId: patientUserId,
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          _MedicationsSection(medications: medications),
                          const SizedBox(height: AppSpacing.xl),
                          Text('Recent history', style: AppTextStyles.heading3),
                          const SizedBox(height: AppSpacing.md),
                        ],
                      ),
                    ),
                  ),
                  _HistorySliver(
                    events: events,
                    medications: medications,
                    medicationMap: medicationMap,
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ReadOnlyBanner extends StatelessWidget {
  final String email;

  const _ReadOnlyBanner({required this.email});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.warningBackground,
      child: Row(
        children: [
          Icon(Icons.visibility_rounded,
              size: AppSpacing.iconSm, color: AppColors.warning),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "You are viewing this account",
                  style: AppTextStyles.bodyMediumSemiBold,
                ),
                if (email.isNotEmpty)
                  Text(
                    email,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdherenceSummary extends StatelessWidget {
  final List<DoseEvent> events;
  final List<Medication> medications;

  const _AdherenceSummary({required this.events, required this.medications});

  @override
  Widget build(BuildContext context) {
    final adherence30d = calculateAdherence(
      events,
      MedAdherence.days30,
      medications,
    );
    final thisWeek = formatAdherence(events, MedAdherence.days7, medications);
    final thisMonth = formatAdherence(events, MedAdherence.days30, medications);
    final streak = calculateStreak(events, medications);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdherenceRateCard(
          rate: '${adherence30d.toStringAsFixed(0)}%',
          period: '${MedAdherence.days30} days',
        ),
        const SizedBox(height: AppSpacing.lg),
        UserStatsCard(
          thisWeek: thisWeek,
          thisMonth: thisMonth,
          daysStreak: '$streak days without missed dose',
        ),
      ],
    );
  }
}

class _TodaySection extends StatelessWidget {
  final List<Medication> medications;
  final List<DoseEvent> events;
  final String patientUserId;

  const _TodaySection({
    required this.medications,
    required this.events,
    required this.patientUserId,
  });

  String _key(String medicationId, DateTime scheduledAt) =>
      '${medicationId}_${scheduledAt.year}-${scheduledAt.month}-${scheduledAt.day}-${scheduledAt.hour}-${scheduledAt.minute}';

  @override
  Widget build(BuildContext context) {
    final schedule = HomePageHelpers.getTodaySchedule(medications);

    final eventsByKey = <String, DoseEvent>{
      for (final e in events) _key(e.medicationId, e.scheduledAt): e,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Today's doses", style: AppTextStyles.heading3),
        const SizedBox(height: AppSpacing.md),
        if (schedule.isEmpty)
          AppCard(
            child: Text(
              'No doses scheduled for today.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          )
        else
          ...schedule.map((slot) {
            final medication = slot['medication'] as Medication;
            final scheduledAt = slot['timeObject'] as DateTime;
            final key = _key(medication.id, scheduledAt);
            final event = eventsByKey[key] ??
                DoseEvent(
                  userId: patientUserId,
                  medicationId: medication.id,
                  scheduledAt: scheduledAt,
                  takenAt: null,
                );

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${medication.name} ${medication.dosage}',
                            style: AppTextStyles.bodyMediumSemiBold,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            formatTimeHm(scheduledAt),
                            style: TextStyle(
                              fontSize: AppTextSizes.bodySmall,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    DoseStatusChip(event: event),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _MedicationsSection extends StatelessWidget {
  final List<Medication> medications;

  const _MedicationsSection({required this.medications});

  @override
  Widget build(BuildContext context) {
    final sorted = [...medications]
      ..sort((a, b) {
        if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Medications', style: AppTextStyles.heading3),
        const SizedBox(height: AppSpacing.md),
        if (sorted.isEmpty)
          AppCard(
            child: Text(
              'No medications yet.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          )
        else
          ...sorted.map(
            (med) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${med.name} ${med.dosage}',
                            style: AppTextStyles.heading3,
                          ),
                        ),
                        ActiveChip(isActive: med.isActive),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      formatSchedule(med.scheduleDays, med.scheduleTimes),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _HistorySliver extends StatelessWidget {
  final List<DoseEvent> events;
  final List<Medication> medications;
  final Map<String, Medication> medicationMap;

  const _HistorySliver({
    required this.events,
    required this.medications,
    required this.medicationMap,
  });

  @override
  Widget build(BuildContext context) {
    final allEvents = _addVirtualMissedDoses(events, medications);
    final grouped = _groupEventsByDay(allEvents);
    final sortedDates = grouped.keys.sorted((a, b) => b.compareTo(a));

    if (allEvents.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: AppPadding.page.copyWith(top: 0),
          child: AppCard(
            child: Text(
              'No history yet.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final date = sortedDates[index];
          final dayEvents = grouped[date]!
            ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

          return Padding(
            padding: AppPadding.page.copyWith(top: 0, bottom: 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: AppSpacing.md,
                    top: AppSpacing.lg,
                  ),
                  child: Text(
                    '${relativeDayLabel(date)} - ${formatDateDdMmYyyy(date)}',
                    style: AppTextStyles.bodyMediumSemiBold,
                  ),
                ),
                ...dayEvents.map(
                  (event) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: HistoryDoseEventRow(
                      event: event,
                      medication: medicationMap[event.medicationId],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        childCount: sortedDates.length,
      ),
    );
  }

  List<DoseEvent> _addVirtualMissedDoses(
    List<DoseEvent> existingEvents,
    List<Medication> medications,
  ) {
    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final existingScheduledTimes = <String>{};
    for (final event in existingEvents) {
      existingScheduledTimes.add(_timeKey(event.scheduledAt));
    }

    final virtualEvents = <DoseEvent>[];

    for (final med in medications.where((m) => m.isActive)) {
      final medStart =
          DateTime(med.startDate.year, med.startDate.month, med.startDate.day);
      final today = DateTime(now.year, now.month, now.day);
      final windowStart =
          today.subtract(const Duration(days: MedicationConstants.historyDefaultDays));
      final startDate = medStart.isAfter(windowStart) ? medStart : windowStart;

      for (var date = startDate;
          date.isBefore(endOfToday);
          date = date.add(const Duration(days: 1))) {
        if (!med.scheduleDays.contains(date.weekday)) continue;

        if (med.endDate != null) {
          final medEnd = DateTime(
              med.endDate!.year, med.endDate!.month, med.endDate!.day);
          if (date.isAfter(medEnd)) break;
        }

        for (final timeStr in med.scheduleTimes) {
          final parts = timeStr.split(':');
          final scheduledTime = DateTime(
            date.year,
            date.month,
            date.day,
            int.parse(parts[0]),
            int.parse(parts[1]),
          );

          if (scheduledTime.isAfter(now.subtract(
              const Duration(
                  minutes: MedicationConstants.doseLateThresholdMinutes)))) {
            continue;
          }

          if (!existingScheduledTimes.contains(_timeKey(scheduledTime))) {
            virtualEvents.add(
              DoseEvent(
                userId: med.userId,
                medicationId: med.id,
                scheduledAt: scheduledTime,
                takenAt: null,
              ),
            );
          }
        }
      }
    }

    return [...existingEvents, ...virtualEvents];
  }

  String _timeKey(DateTime dt) =>
      '${dt.year}-${dt.month}-${dt.day}-${dt.hour}-${dt.minute}';

  Map<DateTime, List<DoseEvent>> _groupEventsByDay(List<DoseEvent> events) {
    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final pastEvents = events
        .where((e) =>
            e.scheduledAt.isBefore(endOfToday) ||
            e.scheduledAt.isAtSameMomentAs(endOfToday))
        .toList();

    return groupBy(pastEvents, (DoseEvent event) {
      final date = event.scheduledAt;
      return DateTime(date.year, date.month, date.day);
    });
  }
}
