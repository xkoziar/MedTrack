import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/user.dart';

class UserDatabaseService {
  final _reference = FirebaseFirestore.instance
      .collection('users')
      .withConverter<AppUser>(
        fromFirestore: (snapshot, options) =>
            AppUser.fromJson(snapshot.data()!),
        toFirestore: (value, options) => value.toJson(),
      );

  Future<void> createUser(AppUser user) async {
    await _reference.doc(user.id).set(user);
  }

  Future<AppUser?> getUser(String userId) async {
    final doc = await _reference.doc(userId).get();
    return doc.data();
  }

  Future<void> updateUser(AppUser user) async {
    await _reference.doc(user.id).update(user.toJson());
  }

  Future<void> deleteUser(String userId) async {
    await _reference.doc(userId).delete();
  }

  Stream<AppUser?> observeUser(String userId) {
    return _reference.doc(userId).snapshots().map((snap) {
      return snap.data();
    });
  }
}
