import 'package:collection/collection.dart';
import 'package:med_track/database/model/dose_event.dart';

double calculateAdherence(List<DoseEvent> events, int days) {
  final now = DateTime.now();
  final startDate = now.subtract(Duration(days: days));

  final relevantEvents = events.where((event) {
    return event.scheduledAt.isAfter(startDate) &&
        event.scheduledAt.isBefore(now) &&
        event.status != DoseStatus.pending;
  }).toList();

  if (relevantEvents.isEmpty) {
    return 100.0;
  }

  final takenCount = relevantEvents
      .where((event) => event.status == DoseStatus.taken)
      .length;

  return (takenCount / relevantEvents.length) * 100;
}

String formatAdherence(List<DoseEvent> allEvents, int days) {
  final now = DateTime.now();
  final startDate = now.subtract(Duration(days: days));

  final relevantEvents = allEvents.where((event) {
    return event.scheduledAt.isAfter(startDate) &&
        event.scheduledAt.isBefore(now) &&
        event.status != DoseStatus.pending;
  }).toList();

  final takenCount = relevantEvents
      .where((event) => event.status == DoseStatus.taken)
      .length;

  final totalCount = relevantEvents.length;
  final adherence = totalCount > 0 ? (takenCount / totalCount) * 100 : 100.0;

  return '${adherence.toStringAsFixed(0)}% ($takenCount/$totalCount doses)';
}

int calculateStreak(List<DoseEvent> events) {
  if (events.isEmpty) return 0;

  final relevantEvents = events.where(
    (e) => e.status == DoseStatus.missed || e.status == DoseStatus.taken,
  );

  final eventsByDay = groupBy(relevantEvents, (DoseEvent event) {
    final date = event.scheduledAt;
    return DateTime(date.year, date.month, date.day);
  });

  final today = DateTime.now();
  var currentDate = DateTime(today.year, today.month, today.day);

  final lastMissedDay = eventsByDay.entries
      .lastWhereOrNull(
        (entry) => entry.value.any((e) => e.status == DoseStatus.missed),
      )
      ?.key;

  if (lastMissedDay == null) {
    if (eventsByDay.keys.isEmpty) return 0;
    final firstEventDay = eventsByDay.keys.reduce(
      (a, b) => a.isBefore(b) ? a : b,
    );
    return today.difference(firstEventDay).inDays + 1;
  }

  if (lastMissedDay.isAtSameMomentAs(currentDate)) {
    return 0;
  }

  return currentDate.difference(lastMissedDay).inDays;
}
