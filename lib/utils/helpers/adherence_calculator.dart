import 'package:med_track/database/model/dose_event.dart';
import 'package:med_track/database/model/medication.dart';
import 'package:med_track/utils/constants.dart';

class _DoseCounts {
  final int expected;
  final int taken;

  _DoseCounts(this.expected, this.taken);

  double get adherencePercent => expected > 0 ? (taken / expected) * 100 : 100.0;
}

/// Calculate expected and taken doses from medication schedules and events.
_DoseCounts _calculateDoseCounts(
  List<DoseEvent> events,
  DateTime startDate,
  DateTime endDate,
  List<Medication> medications,
) {
  int expectedDoses = 0;
  int takenDoses = 0;
  final cutoffTime = endDate.subtract(const Duration(minutes: MedicationConstants.doseLateThresholdMinutes));

  final takenScheduledTimes = <String>{};
  for (final e in events.where((e) => isTaken(e))) {
    final normalizedTime = DateTime(
      e.scheduledAt.year,
      e.scheduledAt.month,
      e.scheduledAt.day,
      e.scheduledAt.hour,
      e.scheduledAt.minute,
    );
    takenScheduledTimes.add(_dateTimeKey(normalizedTime));
  }

  for (final med in medications.where((m) => m.isActive)) {
    final medStart = med.startDate.isAfter(startDate) ? med.startDate : startDate;
    final medEnd = med.endDate != null && med.endDate!.isBefore(endDate)
        ? med.endDate!
        : endDate;

    for (var date = DateTime(medStart.year, medStart.month, medStart.day);
        date.isBefore(medEnd);
        date = date.add(const Duration(days: 1))) {
      if (!med.scheduleDays.contains(date.weekday)) continue;

      for (final timeStr in med.scheduleTimes) {
        final parts = timeStr.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final scheduledTime = DateTime(date.year, date.month, date.day, hour, minute);

        if (scheduledTime.isBefore(cutoffTime)) {
          expectedDoses++;
          if (takenScheduledTimes.contains(_dateTimeKey(scheduledTime))) {
            takenDoses++;
          }
        }
      }
    }
  }

  return _DoseCounts(expectedDoses, takenDoses);
}

String _dateTimeKey(DateTime dt) => '${dt.year}-${dt.month}-${dt.day}-${dt.hour}-${dt.minute}';

double calculateAdherence(
  List<DoseEvent> events,
  int days,
  List<Medication> medications,
) {
  final now = DateTime.now();
  final startDate = now.subtract(Duration(days: days));
  return _calculateDoseCounts(events, startDate, now, medications).adherencePercent;
}

String formatAdherence(
  List<DoseEvent> allEvents,
  int days,
  List<Medication> medications,
) {
  final now = DateTime.now();
  final startDate = now.subtract(Duration(days: days));
  final counts = _calculateDoseCounts(allEvents, startDate, now, medications);
  return '${counts.adherencePercent.toStringAsFixed(0)}% (${counts.taken}/${counts.expected} doses)';
}

int calculateStreak(List<DoseEvent> events, List<Medication> medications) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final activeMeds = medications.where((m) => m.isActive).toList();
  if (activeMeds.isEmpty) return 0;

  final earliestStart = activeMeds
      .map((m) => DateTime(m.startDate.year, m.startDate.month, m.startDate.day))
      .reduce((a, b) => a.isBefore(b) ? a : b);

  final takenScheduledTimes = {
    for (final e in events.where((e) => isTaken(e)))
      _dateTimeKey(e.scheduledAt)
  };

  int streak = 0;
  var checkDate = today.subtract(const Duration(days: 1));

  while (!checkDate.isBefore(earliestStart)) {
    final dayResult = _checkDayCompletion(
      checkDate, activeMeds, takenScheduledTimes, now,
    );

    if (dayResult == _DayResult.missed) break;
    if (dayResult == _DayResult.complete) streak++;

    checkDate = checkDate.subtract(const Duration(days: 1));
  }

  return streak;
}

enum _DayResult { complete, missed, noDoses }

_DayResult _checkDayCompletion(
  DateTime date,
  List<Medication> meds,
  Set<String> takenTimes,
  DateTime now,
) {
  bool dayHasDoses = false;
  final cutoff = now.subtract(const Duration(minutes: MedicationConstants.doseLateThresholdMinutes));

  for (final med in meds) {
    final medStart = DateTime(med.startDate.year, med.startDate.month, med.startDate.day);
    if (date.isBefore(medStart)) continue;
    if (med.endDate != null) {
      final medEnd = DateTime(med.endDate!.year, med.endDate!.month, med.endDate!.day);
      if (date.isAfter(medEnd)) continue;
    }
    if (!med.scheduleDays.contains(date.weekday)) continue;

    for (final timeStr in med.scheduleTimes) {
      final parts = timeStr.split(':');
      final scheduledTime = DateTime(
        date.year, date.month, date.day,
        int.parse(parts[0]), int.parse(parts[1]),
      );

      if (scheduledTime.isAfter(cutoff)) continue;

      dayHasDoses = true;
      if (!takenTimes.contains(_dateTimeKey(scheduledTime))) {
        return _DayResult.missed;
      }
    }
  }

  return dayHasDoses ? _DayResult.complete : _DayResult.noDoses;
}
