import 'package:flutter/material.dart';
import 'package:med_track/database/ioc/ioc_container.dart';
import 'package:med_track/database/service/auth_service.dart';
import 'package:med_track/database/service/medication_database_service.dart';
import 'package:med_track/database/service/dose_event_database_service.dart';
import 'package:med_track/database/model/medication.dart';
import 'package:med_track/database/model/dose_event.dart';
import 'package:med_track/utils/constants.dart';
import 'package:med_track/utils/handling_stream_builder.dart';
import 'package:med_track/components/common/gradient_header.dart';

import 'home/stats_section.dart';
import 'home/schedule_section.dart';
import 'home/home_helpers.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = get<AuthService>();
  final MedicationDatabaseService _medDbService =
      get<MedicationDatabaseService>();
  final DoseEventDatabaseService _doseEventService =
      get<DoseEventDatabaseService>();

  String? _userId;

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _initializeUser() async {
    final firebaseUser = _authService.user;
    if (firebaseUser != null && mounted) {
      setState(() {
        _userId = firebaseUser.uid;
      });
    }
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _toggleMedication(
    String medicationId,
    DateTime scheduledAt,
    bool currentlyTaken,
  ) async {
    if (_userId == null) return;

    try {
      await _doseEventService.recordDose(
        userId: _userId!,
        medicationId: medicationId,
        scheduledAt: scheduledAt,
        taken: !currentlyTaken,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error recording dose: $e')));
      }
    }
  }

  void _navigateToAddMedication() {
    Navigator.pushNamed(context, '/add-medication').then((_) {
      if (mounted) {
        _refreshData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final userName = _authService.user?.displayName ?? 'User';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: HandlingStreamBuilder<List<Medication>>(
        key: ValueKey('medications_$_userId'),
        stream: _medDbService.observeUserMedications(_userId!),
        builder: (medications) {
          return HandlingStreamBuilder<List<DoseEvent>>(
            key: ValueKey('dose_events_$_userId'),
            stream: _doseEventService.observeTodayEvents(_userId!),
            builder: (doseEvents) {
              final todaySchedule = HomePageHelpers.getTodaySchedule(
                medications,
              );
              final takenMedicationKeys =
                  HomePageHelpers.getTakenMedicationKeys(doseEvents);
              final takenCount = takenMedicationKeys.length;
              final totalToday = HomePageHelpers.todayMedicationsCount(
                medications,
              );
              final activeMedications = HomePageHelpers.activeMedicationsCount(
                medications,
              );

              return RefreshIndicator(
                onRefresh: _refreshData,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    GradientSliverHeader(
                      title: 'Home',
                      subtitle: 'Welcome back, $userName',
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: Colors.white,
                        ),
                        onPressed: _navigateToAddMedication,
                        tooltip: 'Add medication',
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: AppPadding.page,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            StatsSection(
                              takenCount: takenCount,
                              totalToday: totalToday,
                              activeMedicationsCount: activeMedications,
                              totalMedications: medications.length,
                            ),
                            const SizedBox(height: AppSpacing.xxl),
                            ScheduleSection(
                              todaySchedule: todaySchedule,
                              takenMedicationKeys: takenMedicationKeys,
                              medications: medications,
                              takenCount: takenCount,
                              totalToday: totalToday,
                              onToggleMedication: _toggleMedication,
                              onAddMedication: _navigateToAddMedication,
                            ),
                            const SizedBox(height: AppSpacing.xl),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
