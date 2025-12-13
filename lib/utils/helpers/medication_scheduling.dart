/// Utility functions for medication scheduling.
String weekdayNameShort(int isoWeekday) {
  switch (isoWeekday) {
    case 1:
      return 'Mon';
    case 2:
      return 'Tue';
    case 3:
      return 'Wed';
    case 4:
      return 'Thu';
    case 5:
      return 'Fri';
    case 6:
      return 'Sat';
    case 7:
      return 'Sun';
    default:
      return '—';
  }
}

/// Formats a DateTime into "dd.MM.yyyy" string.
String formatDateDdMmYyyy(DateTime d) {
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  final yyyy = d.year.toString();
  return '$dd.$mm.$yyyy';
}

/// Formats a DateTime into "HH:mm" string.
String formatTimeHm(DateTime d) {
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

/// Formats schedule days and times into a human-readable string.
String formatSchedule(List<int> days, List<String> times) {
  final safeDays = [...days]..sort();
  final safeTimes = [...times]..sort();

  final dayText = safeDays.isEmpty
      ? ''
      : safeDays.map(weekdayNameShort).join(', ');
  final timeText = safeTimes.isEmpty ? '' : safeTimes.join(', ');

  if (dayText.isEmpty && timeText.isEmpty) return '';
  if (dayText.isEmpty) return timeText;
  if (timeText.isEmpty) return dayText;
  return '$dayText • $timeText';
}

/// Returns 'Today', 'Tomorrow', 'Yesterday' or short weekday name.
String relativeDayLabel(DateTime scheduledAt) {
  final now = DateTime.now();
  final a = DateTime(now.year, now.month, now.day);
  final b = DateTime(scheduledAt.year, scheduledAt.month, scheduledAt.day);
  final diff = b.difference(a).inDays;

  if (diff == 0) return 'Today';
  if (diff == -1) return 'Yesterday';
  if (diff == 1) return 'Tomorrow';
  return weekdayNameShort(scheduledAt.weekday);
}

/// Computes the next scheduled DateTime for a medication based on its schedule.
DateTime? computeNextScheduled({
  required DateTime now,
  required List<int> scheduleDays,
  required List<String> scheduleTimes,
  required DateTime? endDate,
  required bool isActive,
}) {
  if (!isActive) return null;
  if (scheduleDays.isEmpty || scheduleTimes.isEmpty) return null;

  final end = endDate == null
      ? null
      : DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

  DateTime? best;

  for (int addDays = 0; addDays < 14; addDays++) {
    final day = now.add(Duration(days: addDays));
    if (!scheduleDays.contains(day.weekday)) continue;

    for (final t in scheduleTimes) {
      final parsed = parseHm(t);
      if (parsed == null) continue;
      final (h, m) = parsed;
      final candidate = DateTime(day.year, day.month, day.day, h, m);
      if (candidate.isBefore(now)) continue;
      if (end != null && candidate.isAfter(end)) continue;

      if (best == null || candidate.isBefore(best)) {
        best = candidate;
      }
    }
  }

  return best;
}

/// Returns \`(hour, minute)\`
(int, int)? parseHm(String hm) {
  final parts = hm.split(':');
  if (parts.length != 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  if (h < 0 || h > 23 || m < 0 || m > 59) return null;
  return (h, m);
}
