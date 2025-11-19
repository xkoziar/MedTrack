import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/medication.dart';

class MedicationDatabaseService {
  final _reference = FirebaseFirestore.instance
      .collection('medications')
      .withConverter<Medication>(
        fromFirestore: (snapshot, options) =>
            Medication.fromJson(snapshot.data()!),
        toFirestore: (value, options) => value.toJson(),
      );

  Future<void> createMedication(Medication medication) async {
    await _reference.doc(medication.id).set(medication);
  }

  Future<Medication?> getMedication(String medicationId) async {
    final doc = await _reference.doc(medicationId).get();
    return doc.data();
  }

  Future<List<Medication>> getUserMedications(String userId) async {
    final query = await _reference.where('userId', isEqualTo: userId).get();
    return query.docs.map((doc) => doc.data()).toList();
  }

  Future<void> updateMedication(Medication medication) async {
    await _reference.doc(medication.id).update(medication.toJson());
  }

  Future<void> deleteMedication(String medicationId) async {
    await _reference.doc(medicationId).delete();
  }

  Stream<List<Medication>> streamUserMedications(String userId) {
    return _reference
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }
}
