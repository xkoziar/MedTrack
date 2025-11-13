import 'package:firebase_auth/firebase_auth.dart';
import 'package:med_track/database/service/user_database_service.dart';

import '../ioc/ioc_container.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  User? get user => _firebaseAuth.currentUser;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) async {
    return await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  Future<void> resetPassword({required String email}) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  Future<void> updateUserName(String userName) async {
    await _firebaseAuth.currentUser?.updateDisplayName(userName);
  }

  Future<void> resetPasswordFromCurrentPassword({
    required String currentPassword,
    required String newPassword,
    required String email,
  }) async {
    AuthCredential credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await _firebaseAuth.currentUser?.reauthenticateWithCredential(credential);
    await _firebaseAuth.currentUser?.updatePassword(newPassword);
  }

  Future<void> deleteUser({
    required String currentPassword,
    required String email,
  }) async {
    AuthCredential credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await _firebaseAuth.currentUser?.reauthenticateWithCredential(credential);

    final userId = _firebaseAuth.currentUser!.uid;
    final userDbService = get<UserDatabaseService>();
    await userDbService.deleteUser(userId);

    await _firebaseAuth.currentUser?.delete();
    await signOut();
  }
}
