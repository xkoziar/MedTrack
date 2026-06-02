import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:med_track/database/service/notification_service.dart';
import 'package:med_track/database/model/medication.dart';
import 'package:med_track/database/repository/firestore_repository.dart';

class MedicationDatabaseService extends FirestoreRepository<Medication> {
  MedicationDatabaseService()
    : super(
        collectionPath: 'medications',
        fromJson: (json, id) => Medication.fromJson(json, id: id),
        toJson: (medication) => medication.toJson(),
      );

  Future<List<Medication>> getUserMedications(String userId) async {
    final query = await FirebaseFirestore.instance
        .collection('medications')
        .where('userId', isEqualTo: userId)
        .get();

    return query.docs
        .map((doc) => Medication.fromJson(doc.data(), id: doc.id))
        .toList();
  }

  Stream<List<Medication>> observeUserMedications(String userId) {
    return FirebaseFirestore.instance
        .collection('medications')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Medication.fromJson(doc.data(), id: doc.id))
              .toList(),
        );
  }

  @override
  Future<void> create(Medication entity) async {
    await super.create(entity);
    NotificationService.reschedule();
  }

  @override
  Future<void> update(String id, Medication entity) async {
    await super.update(id, entity);
    NotificationService.reschedule();
  }

  @override
  Future<void> delete(String id) async {
    final db = FirebaseFirestore.instance;
    final batch = db.batch();

    final doseEventsQuery = db
        .collection('dose_events')
        .where('medicationId', isEqualTo: id);
    final doseEventsSnapshot = await doseEventsQuery.get();

    for (final doc in doseEventsSnapshot.docs) {
      batch.delete(doc.reference);
    }

    final medicationDocRef = ref.doc(id);
    batch.delete(medicationDocRef);

    await batch.commit();

    NotificationService.reschedule();
  }
}
