import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type; // 'rate' | 'general'
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
  });

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return AppNotification(
      id: doc.id,
      title: (d['title'] as String?) ?? '',
      body: (d['body'] as String?) ?? '',
      type: (d['type'] as String?) ?? 'general',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class NotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('notifications');

  Stream<List<AppNotification>> watchLatest({int limit = 40}) => _col
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(AppNotification.fromDoc).toList());

  /// Is user ne notifications aakhri baar kab dekhi (users/{uid}.notifSeenAt).
  Stream<DateTime?> watchSeenAt() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((s) => (s.data()?['notifSeenAt'] as Timestamp?)?.toDate());
  }

  Future<void> markAllSeen() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _db
        .collection('users')
        .doc(uid)
        .set({'notifSeenAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }

  /// Sirf admin (rules se enforce).
  Future<void> send({
    required String title,
    required String body,
    String type = 'general',
  }) async {
    await _col.add({
      'title': title,
      'body': body,
      'type': type,
      'createdAt': FieldValue.serverTimestamp(),
      'sentBy': FirebaseAuth.instance.currentUser?.uid ?? '',
    });
  }

  Future<void> delete(String id) => _col.doc(id).delete();
}