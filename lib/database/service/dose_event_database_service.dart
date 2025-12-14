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

  Stream<List<DoseEvent>> observeDoseEventsForMedication(
      String medicationId) {
    return FirebaseFirestore.instance
        .collection('dose_events')
        .where('medicationId', isEqualTo: medicationId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
          .map((doc) => DoseEvent.fromJson(doc.data(), id: doc.id))
          .toList(),
    );
  }
}
