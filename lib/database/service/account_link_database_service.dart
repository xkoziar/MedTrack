import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:med_track/database/model/account_link.dart';
import 'package:med_track/database/repository/firestore_repository.dart';

class AccountLinkDatabaseService extends FirestoreRepository<AccountLink> {
  AccountLinkDatabaseService()
      : super(
          collectionPath: _collection,
          fromJson: (json, id) => AccountLink.fromJson(json, id: id),
          toJson: (link) => link.toJson(),
        );

  static const _collection = 'account_links';

  /// Links where [userId] is the caregiver (accounts shared *with* this user).
  Stream<List<AccountLink>> observeLinksAsCaregiver(String userId) {
    return FirebaseFirestore.instance
        .collection(_collection)
        .where('caregiverUserId', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AccountLink.fromJson(doc.data(), id: doc.id))
              .toList(),
        );
  }

  /// Links where [userId] is the patient (people who can view this account).
  Stream<List<AccountLink>> observeLinksAsPatient(String userId) {
    return FirebaseFirestore.instance
        .collection(_collection)
        .where('patientUserId', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AccountLink.fromJson(doc.data(), id: doc.id))
              .toList(),
        );
  }

  /// Creates the link only if the same patient/caregiver pair is not linked yet.
  /// Returns the created link, or `null` when a link already existed.
  ///
  /// Relies on the deterministic id from [AccountLink.buildId], so a simple
  /// document lookup is enough to dedup (no composite query/index needed).
  Future<AccountLink?> createLinkIfMissing(AccountLink link) async {
    final existing = await get(link.id);
    if (existing != null) return null;

    await create(link);
    return link;
  }
}
