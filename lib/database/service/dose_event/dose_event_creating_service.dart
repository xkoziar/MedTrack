import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:med_track/database/model/dose_event.dart';
import 'package:med_track/database/model/medication.dart';

class DoseEventCreationService {
  final _db = FirebaseFirestore.instance;

  Future<void> createDoseEventsForMedication(
    Medication medication, {
    int lookAheadDays = 7,
    DateTime? startDate,
  }) async {
    final batch = _db.batch();
    final doseEventsRef = _db.collection('dose_events');
    final start = startDate ?? DateTime.now();
    final startDateOnly = DateTime(start.year, start.month, start.day);

    for (int i = 0; i < lookAheadDays; i++) {
      final date = startDateOnly.add(Duration(days: i));

      final medicationStartDateOnly = DateTime(
        medication.startDate.year,
        medication.startDate.month,
        medication.startDate.day,
      );
      if (date.isBefore(medicationStartDateOnly)) continue;

      if (medication.endDate != null && date.isAfter(medication.endDate!)) {
        continue;
      }

      if (medication.scheduleDays.contains(date.weekday)) {
        for (final timeStr in medication.scheduleTimes) {
          final timeParts = timeStr.split(':');
          final hour = int.parse(timeParts[0]);
          final minute = int.parse(timeParts[1]);
          final scheduledAt = DateTime(
            date.year,
            date.month,
            date.day,
            hour,
            minute,
          );

          if (scheduledAt.isBefore(start)) continue;

          final existingEventQuery = await doseEventsRef
              .where('medicationId', isEqualTo: medication.id)
              .where('scheduledAt', isEqualTo: scheduledAt)
              .limit(1)
              .get();

          if (existingEventQuery.docs.isEmpty) {
            final newEvent = DoseEvent(
              userId: medication.userId,
              medicationId: medication.id,
              scheduledAt: scheduledAt,
            );
            final newDocRef = doseEventsRef.doc(newEvent.id);
            batch.set(
              newDocRef.withConverter<DoseEvent>(
                fromFirestore: (snapshot, _) =>
                    DoseEvent.fromJson(snapshot.data()!, id: snapshot.id),
                toFirestore: (doseEvent, _) => doseEvent.toJson(),
              ),
              newEvent,
            );
          }
        }
      }
    }

    await batch.commit();
  }
}
