import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/user.dart';

class UserDatabaseService {
  final _reference = FirebaseFirestore.instance
      .collection('users')
      .withConverter<User>(
        fromFirestore: (snapshot, options) => User.fromJson(snapshot.data()!),
        toFirestore: (value, options) => value.toJson(),
      );

  Future<void> createUser(User user) async {
    await _reference.doc(user.id).set(user);
  }

  Future<User?> getUser(String userId) async {
    final doc = await _reference.doc(userId).get();
    return doc.data();
  }

  Future<void> updateUser(User user) async {
    await _reference.doc(user.id).update(user.toJson());
  }

  Future<void> deleteUser(String userId) async {
    await _reference.doc(userId).delete();
  }

  Stream<User?> streamUser(String userId) {
    return _reference.doc(userId).snapshots().map((snap) => snap.data());
  }
}
