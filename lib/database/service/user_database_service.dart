import 'package:cloud_firestore/cloud_firestore.dart';

import '../model/user.dart';

class UserDatabaseService {
  final _reference = FirebaseFirestore.instance
      .collection('users')
      .withConverter<User>(
        fromFirestore: (snapshot, options) => User.fromJson(snapshot.data()!),
        toFirestore: (value, options) => value.toJson(),
      );

  Future<void> addUser(User user) async {
    await _reference.add(user);
  }
}
