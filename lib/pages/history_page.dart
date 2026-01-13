import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:med_track/components/common/adherence_rate_provider_card.dart';
import 'package:med_track/components/common/gradient_header.dart';
import 'package:med_track/components/history/history_dose_event_row.dart';
import 'package:med_track/database/ioc/ioc_container.dart';
import 'package:med_track/database/model/dose_event.dart';
import 'package:med_track/database/model/medication.dart';
import 'package:med_track/database/service/auth_service.dart';
import 'package:med_track/database/service/dose_event/dose_event_database_service.dart';
import 'package:med_track/database/service/medication_database_service.dart';
import 'package:med_track/utils/constants.dart';
import 'package:med_track/utils/handling_stream_builder.dart';
import 'package:med_track/utils/helpers/medication_scheduling.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _authService = get<AuthService>();
  final _doseEventDbService = get<DoseEventDatabaseService>();
  final _medicationDbService = get<MedicationDatabaseService>();
  late final String? _userId = _authService.user?.uid;

  final _scrollController = ScrollController();
  final List<DoseEvent> _events = [];
  DocumentSnapshot? _lastVisible;
  bool _isLoading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    if (_userId != null) {
      _loadMoreEvents();
      _scrollController.addListener(() {
        if (_scrollController.position.pixels >=
                _scrollController.position.maxScrollExtent * 0.9 &&
            !_isLoading) {
          _loadMoreEvents();
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMoreEvents() async {
    if (_isLoading || !_hasMore || _userId == null) return;

    setState(() => _isLoading = true);

    final (newEvents, lastDoc) = await _doseEventDbService
        .getPaginatedUserDoseEvents(_userId, lastVisible: _lastVisible);

    setState(() {
      _isLoading = false;
      _events.addAll(newEvents);
      _lastVisible = lastDoc;
      _hasMore = newEvents.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return const Scaffold(body: Center(child: Text('No logged-in user')));
    }

    return Scaffold(
      body: HandlingStreamBuilder<List<Medication>>(
        stream: _medicationDbService.observeUserMedications(_userId),
        builder: (medications) {
          final medicationMap = {for (var m in medications) m.id: m};
          return HandlingStreamBuilder<List<DoseEvent>>(
            stream: _doseEventDbService.observeUserDoseEvents(_userId),
            builder: (events) {
              // Generate virtual missed doses for display
              final allEvents = _addVirtualMissedDoses(events, medications);
              final groupedEvents = _groupEventsByDay(allEvents);
              final sortedDates = groupedEvents.keys.sorted(
                (a, b) => b.compareTo(a),
              );

              return CustomScrollView(
                slivers: [
                  const GradientSliverHeader(
                    title: 'History',
                    subtitle: 'Overview of medication use',
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: AppPadding.page,
                      child: AdherenceRateProviderCard(userId: _userId),
                    ),
                  ),
                  if (allEvents.isEmpty)
                    const SliverFillRemaining(
                      child: Center(child: Text('No history yet.')),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final date = sortedDates[index];
                        final dayEvents = groupedEvents[date]!;
                        return Padding(
                          padding: AppPadding.page.copyWith(top: 0, bottom: 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.md,
                                  top: AppSpacing.xl,
                                ),
                                child: Text(
                                  '${relativeDayLabel(date)} - ${formatDateDdMmYyyy(date)}',
                                  style: AppTextStyles.heading3,
                                ),
                              ),
                              ...dayEvents.map(
                                (event) => Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpacing.sm,
                                  ),
                                  child: HistoryDoseEventRow(
                                    event: event,
                                    medication:
                                        medicationMap[event.medicationId],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }, childCount: sortedDates.length),
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
      final medStart = DateTime(med.startDate.year, med.startDate.month, med.startDate.day);
      final today = DateTime(now.year, now.month, now.day);
      final startDate = medStart.isAfter(today.subtract(const Duration(days: MedicationConstants.historyDefaultDays)))
          ? medStart
          : today.subtract(const Duration(days: MedicationConstants.historyDefaultDays));

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
    }

    return [...existingEvents, ...virtualEvents];
  }

  String _timeKey(DateTime dt) => '${dt.year}-${dt.month}-${dt.day}-${dt.hour}-${dt.minute}';

  Map<DateTime, List<DoseEvent>> _groupEventsByDay(List<DoseEvent> events) {
    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final pastEvents = events.where((e) =>
      e.scheduledAt.isBefore(endOfToday) || e.scheduledAt.isAtSameMomentAs(endOfToday)
    ).toList();

    return groupBy(pastEvents, (DoseEvent event) {
      final date = event.scheduledAt;
      return DateTime(date.year, date.month, date.day);
    });
  }
}
