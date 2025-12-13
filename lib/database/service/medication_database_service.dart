import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/medication.dart';
import '../repository/firestore_repository.dart';

class MedicationDatabaseService extends FirestoreRepository<Medication> {
  MedicationDatabaseService()
    : super(
        collectionPath: 'medications',
        fromJson: (json, id) => Medication.fromJson(json, id: id),
        toJson: (medication) => medication.toJson(),
      );

  // ----------------------------------------------
  // CUSTOM METHODS → specific to Medication entity
  // ----------------------------------------------

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
}
