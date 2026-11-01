import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

/// Wraps Firebase Auth (email/password) + a simple admin check.
///
/// "Continue with Google / Apple" buttons in the UI are NOT wired here
/// on purpose — those need extra native setup outside code (SHA-1 key
/// registered in Firebase console for Android; Sign in with Apple
/// capability + entitlement in Xcode for iOS). Wire them once that
/// native setup is done; for now they show a "coming soon" message.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;

  /// Fires whenever login state changes (login, logout, app start).
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
    String phone = '',
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await cred.user?.updateDisplayName(name.trim());

      // Create the matching profile document in Firestore.
      await _db.collection('users').doc(cred.user!.uid).set({
        'name': name.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'rewardPoints': 0,
        'totalPurchasesInr': 0,
        'savedItems': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyMessage(e));
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyMessage(e));
    }
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyMessage(e));
    }
  }

  /// Account hamesha ke liye delete. Password se dobara login karwata hai
  /// (Firebase security ke liye zaroori), phir profile doc aur login hatata hai.
  Future<void> deleteAccount(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw AuthException('Pehle login karo');
    }
    try {
      final cred = EmailAuthProvider.credential(email: user.email!, password: password);
      await user.reauthenticateWithCredential(cred);
      try {
        await _db.collection('users').doc(user.uid).delete();
      } catch (_) {}
      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyMessage(e));
    }
  }

  /// True if the logged-in user has an /admins/{uid} doc — see
  /// firestore.rules. Add admin docs manually from the Firebase Console.
  Future<bool> isAdmin() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    final doc = await _db.collection('admins').doc(uid).get();
    return doc.exists;
  }

  String _friendlyMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Ye email/number se koi account nahi mila';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Password galat hai';
      case 'email-already-in-use':
        return 'Ye email pehle se register hai, login karo';
      case 'weak-password':
        return 'Password kam se kam 6 characters ka hona chahiye';
      case 'invalid-email':
        return 'Email sahi format me nahi hai';
      case 'network-request-failed':
        return 'Internet check karo';
      default:
        return e.message ?? 'Kuch galat ho gaya, dobara try karo';
    }
  }
}