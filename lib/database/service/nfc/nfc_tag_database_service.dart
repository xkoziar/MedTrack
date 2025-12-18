import 'package:cloud_firestore/cloud_firestore.dart';
import '../../model/nfc_tag.dart';
import '../../repository/firestore_repository.dart';

class NfcTagDatabaseService extends FirestoreRepository<NfcTag> {
  NfcTagDatabaseService()
      : super(
          collectionPath: 'nfc_tags',
          fromJson: (json, id) => NfcTag.fromJson(json, id: id),
          toJson: (tag) => tag.toJson(),
        );

  // Get all NFC tags for a user
  Future<List<NfcTag>> getUserTags(String userId) async {
    final query = await FirebaseFirestore.instance
        .collection('nfc_tags')
        .where('userId', isEqualTo: userId)
        .get();

    return query.docs
        .map((doc) => NfcTag.fromJson(doc.data(), id: doc.id))
        .toList();
  }

  // Stream of user's NFC tags
  Stream<List<NfcTag>> observeUserTags(String userId) {
    return FirebaseFirestore.instance
        .collection('nfc_tags')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => NfcTag.fromJson(doc.data(), id: doc.id))
              .toList(),
        );
  }

  // Find tag by NFC chip ID
  Future<NfcTag?> findByTagId(String userId, String tagId) async {
    final query = await FirebaseFirestore.instance
        .collection('nfc_tags')
        .where('userId', isEqualTo: userId)
        .where('tagId', isEqualTo: tagId)
        .get();

    if (query.docs.isEmpty) return null;
    return NfcTag.fromJson(query.docs.first.data(), id: query.docs.first.id);
  }

  // Get tags for a specific medication
  Future<List<NfcTag>> getTagsForMedication(
    String userId,
    String medicationId,
  ) async {
    final allTags = await getUserTags(userId);
    return allTags
        .where((tag) => tag.medicationIds.contains(medicationId))
        .toList();
  }

  // Add medication to tag
  Future<void> addMedicationToTag(String tagId, String medicationId) async {
    final tag = await get(tagId);
    if (tag == null) return;

    if (!tag.medicationIds.contains(medicationId)) {
      final updatedTag = tag.copyWith(
        medicationIds: [...tag.medicationIds, medicationId],
        updatedAt: DateTime.now(),
      );
      await update(tagId, updatedTag);
    }
  }

  // Remove medication from tag
  Future<void> removeMedicationFromTag(
    String tagId,
    String medicationId,
  ) async {
    final tag = await get(tagId);
    if (tag == null) return;

    final updatedMedicationIds = tag.medicationIds
        .where((id) => id != medicationId)
        .toList();

    final updatedTag = tag.copyWith(
      medicationIds: updatedMedicationIds,
      updatedAt: DateTime.now(),
    );
    await update(tagId, updatedTag);
  }

  // Update tag name
  Future<void> updateTagName(String tagId, String newName) async {
    final tag = await get(tagId);
    if (tag == null) return;

    final updatedTag = tag.copyWith(
      name: newName,
      updatedAt: DateTime.now(),
    );
    await update(tagId, updatedTag);
  }
}
