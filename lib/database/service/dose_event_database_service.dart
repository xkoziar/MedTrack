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


  Stream<List<DoseEvent>> observeDoseEventsForMedication(
    String medicationId, {
    int? limit,
  }) {
    Query query = FirebaseFirestore.instance
        .collection('dose_events')
        .where('medicationId', isEqualTo: medicationId)
        .orderBy('scheduledAt', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map(
            (doc) => DoseEvent.fromJson(
              doc.data() as Map<String, dynamic>,
              id: doc.id,
            ),
          )
          .toList(),
    );
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
}
