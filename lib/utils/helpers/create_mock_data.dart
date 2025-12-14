import 'package:med_track/database/ioc/ioc_container.dart';
import 'package:med_track/database/model/dose_event.dart';
import 'package:med_track/database/model/medication.dart';
import 'package:med_track/database/service/dose_event_database_service.dart';
import 'package:med_track/database/service/medication_database_service.dart';

void createMockData() {
  final doseEventService = get<DoseEventDatabaseService>();
  final medicationService = get<MedicationDatabaseService>();
  final now = DateTime.now();
  const userId = 'YOUR_USER_ID';

  // --- Mock Medications ---
  final mockMedications = [
    Medication(
      id: 'aspirin_100',
      userId: userId,
      name: 'Aspirin',
      dosage: '100mg',
      startDate: now.subtract(const Duration(days: 30)),
      isActive: true,
      scheduleDays: [1, 2, 3, 4, 5, 6, 7],
      scheduleTimes: ['08:00'],
    ),
    Medication(
      id: 'vitamin_d3',
      userId: userId,
      name: 'Vitamin D3',
      dosage: '1000 IU',
      startDate: now.subtract(const Duration(days: 60)),
      isActive: true,
      scheduleDays: [1, 2, 3, 4, 5, 6, 7],
      scheduleTimes: ['12:00'],
    ),
    Medication(
      id: 'omega_3',
      userId: userId,
      name: 'Omega-3',
      dosage: '500mg',
      startDate: now.subtract(const Duration(days: 10)),
      isActive: true,
      scheduleDays: [1, 3, 5],
      scheduleTimes: ['18:00'],
    ),
    Medication(
      id: 'magnesium_250',
      userId: userId,
      name: 'Magnesium',
      dosage: '250mg',
      startDate: now.subtract(const Duration(days: 5)),
      isActive: true,
      scheduleDays: [1, 2, 3, 4, 5, 6, 7],
      scheduleTimes: ['21:00'],
    ),
  ];

  // --- Mock Dose Events ---
  final mockEvents = [
    // --- Today's Events ---
    DoseEvent(
      userId: userId,
      medicationId: 'aspirin_100',
      scheduledAt: DateTime(now.year, now.month, now.day, 8, 15),
      status: DoseStatus.taken,
      takenAt: DateTime(now.year, now.month, now.day, 8, 15),
    ),
    DoseEvent(
      userId: userId,
      medicationId: 'vitamin_d3',
      scheduledAt: DateTime(now.year, now.month, now.day, 12, 05),
      status: DoseStatus.taken,
      takenAt: DateTime(now.year, now.month, now.day, 12, 05),
    ),
    DoseEvent(
      userId: userId,
      medicationId: 'omega_3',
      scheduledAt: DateTime(now.year, now.month, now.day, 18, 00),
      status: DoseStatus.pending,
    ),

    // --- Yesterday's Events ---
    DoseEvent(
      userId: userId,
      medicationId: 'aspirin_100',
      scheduledAt:
      now.subtract(const Duration(days: 1)).copyWith(hour: 8, minute: 10),
      status: DoseStatus.taken,
      takenAt:
      now.subtract(const Duration(days: 1)).copyWith(hour: 8, minute: 10),
    ),
    DoseEvent(
      userId: userId,
      medicationId: 'vitamin_d3',
      scheduledAt:
      now.subtract(const Duration(days: 1)).copyWith(hour: 12, minute: 0),
      status: DoseStatus.taken,
      takenAt:
      now.subtract(const Duration(days: 1)).copyWith(hour: 12, minute: 0),
    ),
    DoseEvent(
      userId: userId,
      medicationId: 'omega_3',
      scheduledAt:
      now.subtract(const Duration(days: 1)).copyWith(hour: 18, minute: 30),
      status: DoseStatus.taken,
      takenAt:
      now.subtract(const Duration(days: 1)).copyWith(hour: 18, minute: 30),
    ),
    DoseEvent(
      userId: userId,
      medicationId: 'magnesium_250',
      scheduledAt:
      now.subtract(const Duration(days: 1)).copyWith(hour: 21, minute: 0),
      status: DoseStatus.missed,
    ),

    // --- Events from 2 days ago ---
    DoseEvent(
      userId: userId,
      medicationId: 'aspirin_100',
      scheduledAt:
      now.subtract(const Duration(days: 2)).copyWith(hour: 8, minute: 0),
      status: DoseStatus.taken,
      takenAt:
      now.subtract(const Duration(days: 2)).copyWith(hour: 8, minute: 5),
    ),
    DoseEvent(
      userId: userId,
      medicationId: 'vitamin_d3',
      scheduledAt:
      now.subtract(const Duration(days: 2)).copyWith(hour: 12, minute: 0),
      status: DoseStatus.skipped,
    ),
    DoseEvent(
      userId: userId,
      medicationId: 'omega_3',
      scheduledAt:
      now.subtract(const Duration(days: 2)).copyWith(hour: 18, minute: 0),
      status: DoseStatus.missed,
    ),
  ];

  for (final medication in mockMedications) {
    medicationService.create(medication);
  }
  for (final event in mockEvents) {
    doseEventService.create(event);
  }
}
