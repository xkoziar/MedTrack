import 'package:med_track/database/model/medication.dart';
import 'package:med_track/database/model/dose_event.dart';

class HomePageHelpers {
  static List<Map<String, dynamic>> getTodaySchedule(
    List<Medication> medications,
  ) {
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

  static Set<String> getTakenMedicationKeys(List<DoseEvent> events) {
    return events.where((e) => e.status == DoseStatus.taken).map((e) {
      final time =
          '${e.scheduledAt.hour.toString().padLeft(2, '0')}:${e.scheduledAt.minute.toString().padLeft(2, '0')}';
      return '${e.medicationId}_$time';
    }).toSet();
  }

  static int todayMedicationsCount(List<Medication> medications) {
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

  static int activeMedicationsCount(List<Medication> medications) {
    return medications.where((m) => m.isActive).length;
  }
}
