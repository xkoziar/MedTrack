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
              final groupedEvents = _groupEventsByDay(events);
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
                  if (events.isEmpty)
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

  Map<DateTime, List<DoseEvent>> _groupEventsByDay(List<DoseEvent> events) {
    return groupBy(events, (DoseEvent event) {
      final date = event.scheduledAt;
      return DateTime(date.year, date.month, date.day);
    });
  }
}
