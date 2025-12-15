import 'package:flutter/material.dart';
import 'package:med_track/database/ioc/ioc_container.dart';
import 'package:med_track/database/service/auth_service.dart';
import 'package:med_track/database/service/user_database_service.dart';
import 'package:med_track/database/service/medication_database_service.dart';
import 'package:med_track/database/service/dose_event_database_service.dart';
import 'package:med_track/database/model/medication.dart';
import 'package:med_track/database/model/dose_event.dart';
import 'package:med_track/utils/constants.dart';
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
  final UserDatabaseService _userDbService = get<UserDatabaseService>();
  final MedicationDatabaseService _medDbService = get<MedicationDatabaseService>();
  final DoseEventDatabaseService _doseEventService = get<DoseEventDatabaseService>();

  String _userName = '';
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
      await _loadUserName();
    }
  }

  Future<void> _loadUserName() async {
    if (_userId == null || !mounted) return;

    try {
      final user = await _userDbService.get(_userId!);
      if (mounted) {
        setState(() {
          _userName = user?.name ?? 'User';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userName = 'User';
        });
      }
    }
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    await _loadUserName();
    if (mounted) {
      setState(() {});
    }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error recording dose: $e')),
        );
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: StreamBuilder<List<Medication>>(
        key: ValueKey('medications_$_userId'),
        stream: _medDbService.observeUserMedications(_userId!),
        builder: (context, medicationSnapshot) {
          if (medicationSnapshot.connectionState == ConnectionState.waiting) {
            return CustomScrollView(
              slivers: [
                GradientSliverHeader(
                  title: 'Home',
                  subtitle: 'Welcome back, $_userName',
                ),
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            );
          }

          if (medicationSnapshot.hasError) {
            return CustomScrollView(
              slivers: [
                GradientSliverHeader(
                  title: 'Home',
                  subtitle: 'Welcome back, $_userName',
                ),
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: AppPadding.page,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 64, color: Colors.red),
                          const SizedBox(height: AppSpacing.xl),
                          Text(
                            'Error loading medications',
                            style: AppTextStyles.heading3,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            medicationSnapshot.error.toString(),
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          final medications = medicationSnapshot.data ?? [];

          return StreamBuilder<List<DoseEvent>>(
            key: ValueKey('dose_events_$_userId'),
            stream: _doseEventService.observeTodayEvents(_userId!),
            builder: (context, doseEventSnapshot) {
              if (doseEventSnapshot.connectionState == ConnectionState.waiting) {
                return CustomScrollView(
                  slivers: [
                    GradientSliverHeader(
                      title: 'Home',
                      subtitle: 'Welcome back, $_userName',
                    ),
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
                );
              }

              final doseEvents = doseEventSnapshot.data ?? [];
              final todaySchedule = HomePageHelpers.getTodaySchedule(medications);
              final takenMedicationKeys = HomePageHelpers.getTakenMedicationKeys(doseEvents);
              final takenCount = takenMedicationKeys.length;
              final totalToday = HomePageHelpers.todayMedicationsCount(medications);
              final activeMedications = HomePageHelpers.activeMedicationsCount(medications);

              return RefreshIndicator(
                onRefresh: _refreshData,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    GradientSliverHeader(
                      title: 'Home',
                      subtitle: 'Welcome back, $_userName',
                      trailing: IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: Colors.white),
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
