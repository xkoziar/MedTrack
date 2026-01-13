import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:med_track/database/model/dose_event.dart';
import 'package:med_track/database/repository/firestore_repository.dart';

class DoseEventDatabaseService extends FirestoreRepository<DoseEvent> {
  DoseEventDatabaseService()
    : super(
        collectionPath: 'dose_events',
        fromJson: (json, id) => DoseEvent.fromJson(json, id: id),
        toJson: (doseEvent) => doseEvent.toJson(),
      );

  Stream<List<DoseEvent>> observeMedicationEventsTodayAndEarlier(
    String medicationId, {
    int? limit,
  }) {
    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final query = FirebaseFirestore.instance
        .collection('dose_events')
        .where('medicationId', isEqualTo: medicationId);

    return query.snapshots().map((snapshot) {
      final allEvents = snapshot.docs
          .map((doc) => DoseEvent.fromJson(doc.data(), id: doc.id))
          .toList();

      final pastAndTodayEvents = allEvents
          .where((event) => !event.scheduledAt.isAfter(endOfToday))
          .toList();

      pastAndTodayEvents.sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

      if (limit != null && pastAndTodayEvents.length > limit) {
        return pastAndTodayEvents.sublist(0, limit);
      }

      return pastAndTodayEvents;
    });
  }

  Future<(List<DoseEvent>, DocumentSnapshot?)> getPaginatedUserDoseEvents(
    String userId, {
    int limit = 20,
    DocumentSnapshot? lastVisible,
  }) async {
    Query query = FirebaseFirestore.instance
        .collection('dose_events')
        .where('userId', isEqualTo: userId)
        .orderBy('scheduledAt', descending: true)
        .limit(limit);

    if (lastVisible != null) {
      query = query.startAfterDocument(lastVisible);
    }

    final snapshot = await query.get();
    final events = snapshot.docs
        .map(
          (doc) => DoseEvent.fromJson(
            doc.data() as Map<String, dynamic>,
            id: doc.id,
          ),
        )
        .toList();

    final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;

    return (events, lastDoc);
  }

  Stream<List<DoseEvent>> observeUserDoseEvents(String userId) {
    return FirebaseFirestore.instance
        .collection('dose_events')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => DoseEvent.fromJson(doc.data(), id: doc.id))
              .toList(),
        );
  }

  Future<List<DoseEvent>> getUpcomingUserDoseEventsForMedication(
    String userId,
    String medicationId, {
    DateTime? from,
  }) async {
    final start = from ?? DateTime.now();

    final query = FirebaseFirestore.instance
        .collection('dose_events')
        .where('medicationId', isEqualTo: medicationId);

    final snapshot = await query.get();

    final allEvents = snapshot.docs
        .map((doc) => DoseEvent.fromJson(doc.data(), id: doc.id))
        .toList();

    final upcomingEvents = allEvents
        .where(
          (event) =>
              event.userId == userId && !event.scheduledAt.isBefore(start),
        )
        .toList();

    upcomingEvents.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    return upcomingEvents;
  }

  Future<void> deleteListOfDoseEvents(List<DoseEvent> events) async {
    final batch = FirebaseFirestore.instance.batch();
    final doseEventsRef = FirebaseFirestore.instance.collection('dose_events');

    for (final event in events) {
      final docRef = doseEventsRef.doc(event.id);
      batch.delete(docRef);
    }

    await batch.commit();
  }

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
      if (taken) {
        await update(
          existingEvent.id,
          existingEvent.copyWith(
            takenAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      } else {
        await update(
          existingEvent.id,
          DoseEvent(
            id: existingEvent.id,
            userId: existingEvent.userId,
            medicationId: existingEvent.medicationId,
            scheduledAt: existingEvent.scheduledAt,
            takenAt: null,
            createdAt: existingEvent.createdAt,
            updatedAt: DateTime.now(),
          ),
        );
      }
    } else if (taken) {
      final event = DoseEvent(
        userId: userId,
        medicationId: medicationId,
        scheduledAt: scheduledAt,
        takenAt: DateTime.now(),
      );
      await create(event);
    }
  }

  Future<DoseEvent?> findEventBySchedule({
    required String userId,
    required String medicationId,
    required DateTime scheduledAt,
  }) async {
    final query = await FirebaseFirestore.instance
        .collection('dose_events')
        .where('userId', isEqualTo: userId)
        .get();

    final events = query.docs
        .map((doc) => DoseEvent.fromJson(doc.data(), id: doc.id))
        .where(
          (event) =>
              event.medicationId == medicationId &&
              event.scheduledAt.year == scheduledAt.year &&
              event.scheduledAt.month == scheduledAt.month &&
              event.scheduledAt.day == scheduledAt.day &&
              event.scheduledAt.hour == scheduledAt.hour &&
              event.scheduledAt.minute == scheduledAt.minute,
        )
        .toList();

    return events.isEmpty ? null : events.first;
  }

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
              .where(
                (event) =>
                    event.scheduledAt.isAfter(
                      startOfDay.subtract(const Duration(seconds: 1)),
                    ) &&
                    event.scheduledAt.isBefore(
                      endOfDay.add(const Duration(seconds: 1)),
                    ),
              )
              .toList();
        });
  }

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
        .where(
          (event) =>
              event.scheduledAt.isAfter(
                startOfDay.subtract(const Duration(seconds: 1)),
              ) &&
              event.scheduledAt.isBefore(
                endOfDay.add(const Duration(seconds: 1)),
              ),
        )
        .toList();
  }

  Future<List<DoseEvent>> getForMedicationInRange(
    String medicationId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final query = await FirebaseFirestore.instance
        .collection('dose_events')
        .where('medicationId', isEqualTo: medicationId)
        .get();

    return query.docs
        .map((doc) => DoseEvent.fromJson(doc.data(), id: doc.id))
        .where((event) =>
            !event.scheduledAt.isBefore(startDate) &&
            !event.scheduledAt.isAfter(endDate))
        .toList();
  }

  Future<void> createBatch(List<DoseEvent> events) async {
    if (events.isEmpty) return;
    
    final batch = FirebaseFirestore.instance.batch();
    final collection = FirebaseFirestore.instance.collection('dose_events');

    for (final event in events) {
      batch.set(collection.doc(event.id), event.toJson());
    }

    await batch.commit();
  }
}
