import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfile {
  final String name;
  final String email;
  final String phone;
  final int rewardPoints;
  final double totalPurchasesInr;
  final int savedItems;

  /// PAN number, saved once the user enters it for a large purchase
  /// (see investment_screen.dart's ₹2 lakh PAN requirement). Stored
  /// only on the user's own doc — never duplicated in full anywhere
  /// else; only a masked version goes into transaction records.
  final String pan;

  const UserProfile({
    required this.name,
    required this.email,
    required this.phone,
    required this.rewardPoints,
    required this.totalPurchasesInr,
    required this.savedItems,
    this.pan = '',
  });

  factory UserProfile.fromMap(Map<String, dynamic> data) {
    return UserProfile(
      name: (data['name'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      phone: (data['phone'] as String?) ?? '',
      rewardPoints: (data['rewardPoints'] as num?)?.toInt() ?? 0,
      totalPurchasesInr: (data['totalPurchasesInr'] as num?)?.toDouble() ?? 0,
      savedItems: (data['savedItems'] as num?)?.toInt() ?? 0,
      pan: (data['pan'] as String?) ?? '',
    );
  }
}

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  Future<UserProfile?> getProfile() async {
    final uid = _uid;
    if (uid == null) return null;
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserProfile.fromMap(doc.data()!);
  }

  Stream<UserProfile?> watchProfile() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _db.collection('users').doc(uid).snapshots().map(
          (doc) => doc.exists ? UserProfile.fromMap(doc.data()!) : null,
    );
  }

  Future<void> updateProfile({String? name, String? phone, String? pan}) async {
    final uid = _uid;
    if (uid == null) return;
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (phone != null) updates['phone'] = phone;
    if (pan != null) updates['pan'] = pan.toUpperCase().trim();
    if (updates.isEmpty) return;
    await _db.collection('users').doc(uid).set(updates, SetOptions(merge: true));
  }
}