import 'package:flutter/material.dart';
import 'package:med_track/database/ioc/ioc_container.dart';
import 'package:med_track/database/service/auth_service.dart';
import 'package:med_track/database/service/user_database_service.dart';
import 'package:med_track/database/model/medication.dart';
import 'package:med_track/utils/constants.dart';
import 'package:intl/intl.dart';

import 'home/home_header.dart';
import 'home/medication_item.dart';
import 'home/empty_state.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = get<AuthService>();
  final UserDatabaseService _userDbService = get<UserDatabaseService>();

  String _userName = '';
  bool _isLoading = false;
  final List<Medication> _medications = [];
  final Set<String> _takenMedications = {};

  @override
  void dispose() {
    _medications.clear();
    _takenMedications.clear();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final userId = _authService.user?.uid;
    if (userId != null) {
      final user = await _userDbService.get(userId);
      final medications = <Medication>[];
      setState(() {
        _userName = user?.name ?? 'User';
        _medications.clear();
        _medications.addAll(medications);
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getTodaySchedule() {
    final now = DateTime.now();
    final currentWeekday = now.weekday;
    final schedule = <Map<String, dynamic>>[];
    final timeFormat = DateFormat('HH:mm');

    for (final med in _medications) {
      if (med.scheduleDays.contains(currentWeekday)) {
        for (final time in med.scheduleTimes) {
          schedule.add({
            'medicationId': med.id,
            'name': med.name,
            'dosage': med.dosage,
            'timeObject': time,
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

  void _toggleMedication(String medicationId) {
    setState(() {
      if (_takenMedications.contains(medicationId)) {
        _takenMedications.remove(medicationId);
      } else {
        _takenMedications.add(medicationId);
      }
    });
  }

  Future<void> _addSampleData() async {
    final userId = _authService.user?.uid;
    if (userId != null) {
      setState(() => _isLoading = true);
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final todaySchedule = _getTodaySchedule();

    return Scaffold(
      appBar: AppBar(
        title: const Text('MedTrack'),
        actions: [
          IconButton(
            icon: const Icon(Icons.science),
            onPressed: _addSampleData,
            tooltip: 'Add sample data (DEV)',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {},
            tooltip: 'Add medication',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: AppPadding.page,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HomeHeader(userName: _userName),
                  const SizedBox(height: AppSpacing.xxl),
                  Text('Today\'s Schedule', style: AppTextStyles.heading3),
                  const SizedBox(height: AppSpacing.lg),
                  todaySchedule.isEmpty
                      ? const SizedBox(height: 300, child: EmptyState())
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: todaySchedule.length,
                          itemBuilder: (context, index) {
                            final item = todaySchedule[index];
                            final scheduleKey =
                                '${item['medicationId']}_${item['time']}';
                            return MedicationItem(
                              name: '${item['name']} (${item['dosage']})',
                              time: item['time'],
                              isTaken: _takenMedications.contains(scheduleKey),
                              onTap: () => _toggleMedication(scheduleKey),
                            );
                          },
                        ),
                ],
              ),
            ),
    );
  }
}
