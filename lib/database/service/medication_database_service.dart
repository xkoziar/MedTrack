import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/medication.dart';
import '../repository/firestore_repository.dart';

class MedicationDatabaseService extends FirestoreRepository<Medication> {
  MedicationDatabaseService()
    : super(
        collectionPath: 'medications',
        fromJson: (json, id) => Medication.fromJson(json),
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

    return query.docs.map((doc) => Medication.fromJson(doc.data())).toList();
  }
}
