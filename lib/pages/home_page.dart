import 'package:flutter/material.dart';
import 'package:med_track/database/ioc/ioc_container.dart';
import 'package:med_track/database/service/auth_service.dart';
import 'package:med_track/database/service/user_database_service.dart';
import 'package:med_track/database/service/medication_database_service.dart';
import 'package:med_track/database/service/dose_event_database_service.dart';
import 'package:med_track/database/model/medication.dart';
import 'package:med_track/database/model/dose_event.dart';
import 'package:med_track/utils/constants.dart';
import 'package:med_track/components/common/app_card.dart';
import 'package:med_track/components/common/buttons/primary_button.dart';

import 'home/home_header.dart';
import 'home/medication_item.dart';
import 'home/empty_state.dart';
import 'home/quick_stats_card.dart';
import 'home/tip_card.dart';

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
      setState(() {}); // Trigger rebuild to refresh stream
    }
  }

  List<Map<String, dynamic>> _getTodaySchedule(List<Medication> medications) {
    final now = DateTime.now();
    final currentWeekday = now.weekday;
    final schedule = <Map<String, dynamic>>[];

    for (final med in medications) {
      if (med.isActive && med.scheduleDays.contains(currentWeekday)) {
        for (final timeStr in med.scheduleTimes) {
          final timeParts = timeStr.split(':');
          final scheduleTime = DateTime(
            now.year,
            now.month,
            now.day,
            int.parse(timeParts[0]),
            int.parse(timeParts[1]),
          );

          schedule.add({
            'medicationId': med.id,
            'name': med.name,
            'dosage': med.dosage,
            'time': timeStr,
            'timeObject': scheduleTime,
            'medication': med,
          });
        }
      }
    }

    schedule.sort(
      (a, b) =>
          (a['timeObject'] as DateTime).compareTo(b['timeObject'] as DateTime),
    );
    return schedule;
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

  Set<String> _getTakenMedicationKeys(List<DoseEvent> events) {
    return events
        .where((e) => e.status == DoseStatus.taken)
        .map((e) {
          final time = '${e.scheduledAt.hour.toString().padLeft(2, '0')}:${e.scheduledAt.minute.toString().padLeft(2, '0')}';
          return '${e.medicationId}_$time';
        })
        .toSet();
  }

  int _todayMedicationsCount(List<Medication> medications) {
    final now = DateTime.now();
    final currentWeekday = now.weekday;
    int count = 0;
    for (final med in medications) {
      if (med.isActive && med.scheduleDays.contains(currentWeekday)) {
        count += med.scheduleTimes.length;
      }
    }
    return count;
  }

  int _activeMedicationsCount(List<Medication> medications) {
    return medications.where((m) => m.isActive).length;
  }

  void _navigateToAddMedication() {
    Navigator.pushNamed(context, '/add-medication').then((_) {
      if (mounted) {
        _refreshData();
      }
    });
  }

  double _adherenceRate(int takenCount, int totalToday) {
    if (totalToday == 0) return 0.0;
    return (takenCount / totalToday * 100).clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    // Show loading if user ID not yet initialized
    if (_userId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text('MedTrack', style: AppTextStyles.heading3),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _navigateToAddMedication,
            tooltip: 'Add medication',
            color: AppColors.primary,
          ),
        ],
      ),
      body: StreamBuilder<List<Medication>>(
        key: ValueKey('medications_$_userId'),
        stream: _medDbService.observeUserMedications(_userId!),
        builder: (context, medicationSnapshot) {
          if (medicationSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (medicationSnapshot.hasError) {
            return Center(
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
            );
          }

          final medications = medicationSnapshot.data ?? [];

          return StreamBuilder<List<DoseEvent>>(
            key: ValueKey('dose_events_$_userId'),
            stream: _doseEventService.observeTodayEvents(_userId!),
            builder: (context, doseEventSnapshot) {
              if (doseEventSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final doseEvents = doseEventSnapshot.data ?? [];
              final todaySchedule = _getTodaySchedule(medications);
              final takenMedicationKeys = _getTakenMedicationKeys(doseEvents);
              final takenCount = takenMedicationKeys.length;
              final totalToday = _todayMedicationsCount(medications);

              return RefreshIndicator(
                onRefresh: _refreshData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: AppPadding.page,
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HomeHeader(userName: _userName),
                    const SizedBox(height: AppSpacing.xl),

                    // Statistics Cards
                    Row(
                      children: [
                        Expanded(
                          child: QuickStatsCard(
                            title: 'Today\'s Doses',
                            value: '$takenCount/$totalToday',
                            icon: Icons.schedule,
                            color: AppColors.primary,
                            subtitle: totalToday > 0
                                ? '${_adherenceRate(takenCount, totalToday).toStringAsFixed(0)}% completed'
                                : 'No doses scheduled',
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: QuickStatsCard(
                            title: 'Active Meds',
                            value: '${_activeMedicationsCount(medications)}',
                            icon: Icons.medication,
                            color: AppColors.success,
                            subtitle: medications.isEmpty
                                ? 'Start tracking'
                                : '${medications.length} total',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    // Today's Schedule Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Today\'s Schedule',
                          style: AppTextStyles.heading3,
                        ),
                        if (todaySchedule.isNotEmpty)
                          Text(
                            '${todaySchedule.length} dose${todaySchedule.length != 1 ? 's' : ''}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Schedule List or Empty State
                    if (todaySchedule.isEmpty)
                      Column(
                        children: [
                          AppCard(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const EmptyState(),
                                  const SizedBox(height: AppSpacing.xl),
                                  SizedBox(
                                    width: 200,
                                    child: PrimaryGradientButton(
                                      label: 'Add Medication',
                                      onPressed: _navigateToAddMedication,
                                      icon: const Icon(Icons.add),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (medications.isEmpty) ...[
                            const SizedBox(height: AppSpacing.xl),
                            const TipCard(
                              title: 'Track your medications easily',
                              description:
                                  'Add your medications to get reminders, track adherence, and never miss a dose.',
                              icon: Icons.tips_and_updates,
                            ),
                          ],
                        ],
                      )
                    else
                      Column(
                        children: [
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: todaySchedule.length,
                            itemBuilder: (context, index) {
                              final item = todaySchedule[index];
                              final medicationId = item['medicationId'] as String;
                              final medicationName = item['name'] as String? ?? 'Unknown Medication';
                              final medicationDosage = item['dosage'] as String? ?? '';
                              final medicationTime = item['time'] as String? ?? '';
                              final scheduleTime = item['timeObject'] as DateTime;
                              final scheduleKey = '${medicationId}_$medicationTime';
                              final isTaken = takenMedicationKeys.contains(scheduleKey);

                              return MedicationItem(
                                name: medicationName,
                                time: '$medicationTime • $medicationDosage',
                                isTaken: isTaken,
                                onTap: () => _toggleMedication(
                                  medicationId,
                                  scheduleTime,
                                  isTaken,
                                ),
                              );
                            },
                          ),
                          if (takenCount == totalToday && totalToday > 0) ...[
                            const SizedBox(height: AppSpacing.lg),
                            TipCard(
                              title: 'Great job!',
                              description:
                                  'You\'ve completed all your medications for today. Keep up the excellent work!',
                              icon: Icons.celebration,
                              color: AppColors.success,
                            ),
                          ],
                        ],
                      ),

                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            );
            },
          );
        },
      ),
    );
  }
}
