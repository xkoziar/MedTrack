import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:med_track/database/model/app_user.dart';
import 'package:med_track/database/repository/firestore_repository.dart';

class UserDatabaseService extends FirestoreRepository<AppUser> {
  UserDatabaseService()
      : super(
    collectionPath: 'users',
    fromJson: (json, id) => AppUser.fromJson(json),
    toJson: (user) => user.toJson(),
  );

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
