import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/dose_event.dart';
import '../repository/firestore_repository.dart';

class DoseEventDatabaseService extends FirestoreRepository<DoseEvent> {
  DoseEventDatabaseService()
      : super(
          collectionPath: 'dose_events',
          fromJson: (json, id) => DoseEvent.fromJson(json),
          toJson: (event) => event.toJson(),
        );

  // Get dose events for a specific medication
  Future<List<DoseEvent>> getMedicationEvents(String medicationId) async {
    final query = await FirebaseFirestore.instance
        .collection('dose_events')
        .where('medicationId', isEqualTo: medicationId)
        .orderBy('scheduledAt', descending: true)
        .get();

    return query.docs
        .map((doc) => DoseEvent.fromJson(doc.data(), id: doc.id))
        .toList();
  }

  // Get todays dose events for a user
  Future<List<DoseEvent>> getTodayEvents(String userId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final query = await FirebaseFirestore.instance
        .collection('dose_events')
        .where('userId', isEqualTo: userId)
        .get();

    // Filter in memory to avoid needing a composite index
    return query.docs
        .map((doc) => DoseEvent.fromJson(doc.data(), id: doc.id))
        .where((event) =>
            event.scheduledAt.isAfter(startOfDay.subtract(const Duration(seconds: 1))) &&
            event.scheduledAt.isBefore(endOfDay.add(const Duration(seconds: 1))))
        .toList();
  }

  // Stream of todays events for a user
  Stream<List<DoseEvent>> observeTodayEvents(String userId) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return FirebaseFirestore.instance
        .collection('dose_events')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          // Filter in memory to avoid needing a composite index
          return snapshot.docs
              .map((doc) => DoseEvent.fromJson(doc.data(), id: doc.id))
              .where((event) =>
                  event.scheduledAt.isAfter(startOfDay.subtract(const Duration(seconds: 1))) &&
                  event.scheduledAt.isBefore(endOfDay.add(const Duration(seconds: 1))))
              .toList();
        });
  }

  // Check if a dose event exists for a specific schedule
  Future<DoseEvent?> findEventBySchedule({
    required String userId,
    required String medicationId,
    required DateTime scheduledAt,
  }) async {
    final query = await FirebaseFirestore.instance
        .collection('dose_events')
        .where('userId', isEqualTo: userId)
        .get();

    // Filter in memory to find matching event
    final events = query.docs
        .map((doc) => DoseEvent.fromJson(doc.data(), id: doc.id))
        .where((event) =>
            event.medicationId == medicationId &&
            event.scheduledAt.year == scheduledAt.year &&
            event.scheduledAt.month == scheduledAt.month &&
            event.scheduledAt.day == scheduledAt.day &&
            event.scheduledAt.hour == scheduledAt.hour &&
            event.scheduledAt.minute == scheduledAt.minute)
        .toList();

    return events.isEmpty ? null : events.first;
  }

  // Create or update a dose event
  Future<void> recordDose({
    required String userId,
    required String medicationId,
    required DateTime scheduledAt,
    required bool taken,
  }) async {
    final existingEvent = await findEventBySchedule(
      userId: userId,
      medicationId: medicationId,
      scheduledAt: scheduledAt,
    );

    if (existingEvent != null) {
      // Update existing event
      if (taken) {
        await update(
          existingEvent.id,
          DoseEvent(
            id: existingEvent.id,
            userId: userId,
            medicationId: medicationId,
            scheduledAt: scheduledAt,
            takenAt: DateTime.now(),
            status: DoseStatus.taken,
          ),
        );
      } else {
        // Delete the event if unmarking as taken
        await delete(existingEvent.id);
      }
    } else if (taken) {
      // Create new event
      final event = DoseEvent(
        userId: userId,
        medicationId: medicationId,
        scheduledAt: scheduledAt,
        takenAt: DateTime.now(),
        status: DoseStatus.taken,
      );
      await create(event);
    }
  }
}
