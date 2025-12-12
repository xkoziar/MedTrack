import 'package:cloud_firestore/cloud_firestore.dart';

import '../model/app_user.dart';
import '../repository/firestore_repository.dart';

class UserDatabaseService extends FirestoreRepository<AppUser> {
  UserDatabaseService()
      : super(
    collectionPath: 'users',
    fromJson: (json, id) => AppUser.fromJson(json),
    toJson: (user) => user.toJson(),
  );

  // -----------------------------------------
  // CUSTOM METHODS → specific to User entity
  // -----------------------------------------

  Future<AppUser?> findByEmail(String email) async {
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;

    final data = query.docs.first.data();
    return AppUser.fromJson(data);
  }
}
