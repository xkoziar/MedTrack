import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/dose_event.dart';
import '../repository/firestore_repository.dart';

class DoseEventDatabaseService extends FirestoreRepository<DoseEvent> {
  DoseEventDatabaseService()
    : super(
        collectionPath: 'dose_events',
        fromJson: (json, id) => DoseEvent.fromJson(json, id: id),
        toJson: (doseEvent) => doseEvent.toJson(),
      );

  // ----------------------------------------------
  // CUSTOM METHODS → specific to DoseEvent entity
  // ----------------------------------------------

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

  Future<void> updateDoseEventsStatusToMissed(String userId) async {
    final now = DateTime.now();
    final db = FirebaseFirestore.instance;

    final query = db
        .collection('dose_events')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: DoseStatus.pending.name);

    final snapshot = await query.get();
    if (snapshot.docs.isEmpty) {
      return;
    }

    final batch = db.batch();
    for (final doc in snapshot.docs) {
      final event = DoseEvent.fromJson(doc.data(), id: doc.id);
      if (event.scheduledAt.isBefore(now)) {
        batch.update(doc.reference, {
          'status': DoseStatus.missed.name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    await batch.commit();
  }
}
