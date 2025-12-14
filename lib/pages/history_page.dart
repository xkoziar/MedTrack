import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:med_track/components/common/adherence_rate_provider_card.dart';
import 'package:med_track/components/common/gradient_header.dart';
import 'package:med_track/components/history/history_dose_event_row.dart';
import 'package:med_track/database/ioc/ioc_container.dart';
import 'package:med_track/database/model/dose_event.dart';
import 'package:med_track/database/model/medication.dart';
import 'package:med_track/database/service/auth_service.dart';
import 'package:med_track/database/service/dose_event_database_service.dart';
import 'package:med_track/database/service/medication_database_service.dart';
import 'package:med_track/utils/constants.dart';
import 'package:med_track/utils/handling_stream_builder.dart';
import 'package:med_track/utils/helpers/medication_scheduling.dart';

class HistoryPage extends StatelessWidget {
  HistoryPage({super.key});

  final _authService = get<AuthService>();
  final _doseEventDbService = get<DoseEventDatabaseService>();
  final _medicationDbService = get<MedicationDatabaseService>();
  late final _userId = _authService.user?.uid;

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return const Scaffold(body: Center(child: Text('No logged-in user')));
    }

    return Scaffold(
      body: HandlingStreamBuilder<List<DoseEvent>>(
        stream: _doseEventDbService.observeUserDoseEvents(_userId!),
        builder: (events) {
          return HandlingStreamBuilder<List<Medication>>(
            stream: _medicationDbService.observeUserMedications(_userId!),
            builder: (medications) {
              final medicationMap = {for (var m in medications) m.id: m};
              final groupedEvents = _groupEventsByDay(events);
              final sortedDates =
              groupedEvents.keys.sorted((a, b) => b.compareTo(a));

              return CustomScrollView(
                slivers: [
                  const GradientSliverHeader(
                    title: 'History',
                    subtitle: 'Overview of medication use',
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: AppPadding.page,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AdherenceRateProviderCard(userId: _userId!),
                          const SizedBox(height: AppSpacing.xl),
                          ...sortedDates.map((date) {
                            final dayEvents = groupedEvents[date]!;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpacing.md,
                                    top: AppSpacing.md,
                                  ),
                                  child: Text(
                                    '${relativeDayLabel(date)} - ${formatDateDdMmYyyy(date)}',
                                    style: AppTextStyles.heading3,
                                  ),
                                ),
                                ...dayEvents.map(
                                      (event) => Padding(
                                    padding: const EdgeInsets.only(
                                        bottom: AppSpacing.sm),
                                    child: HistoryDoseEventRow(
                                      event: event,
                                      medication:
                                      medicationMap[event.medicationId],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Map<DateTime, List<DoseEvent>> _groupEventsByDay(List<DoseEvent> events) {
    return groupBy(events, (DoseEvent event) {
      final date = event.scheduledAt;
      return DateTime(date.year, date.month, date.day);
    });
  }
}
