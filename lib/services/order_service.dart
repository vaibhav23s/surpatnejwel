import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum OrderStatus { processing, shipped, delivered, cancelled }

class JewelOrder {
  final String id;
  final String itemName;
  final double amountInr;
  final OrderStatus status;
  final DateTime placedAt;

  const JewelOrder({
    required this.id,
    required this.itemName,
    required this.amountInr,
    required this.status,
    required this.placedAt,
  });

  factory JewelOrder.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return JewelOrder(
      id: doc.id,
      itemName: (data['itemName'] as String?) ?? '',
      amountInr: (data['amountInr'] as num?)?.toDouble() ?? 0,
      status: OrderStatus.values.firstWhere(
            (s) => s.name == data['status'],
        orElse: () => OrderStatus.processing,
      ),
      placedAt: (data['placedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// NOTE: there's no cart/checkout screen in the app yet, so nothing
/// calls [placeOrder] currently — this just sets up the Firestore
/// schema + queries so the Profile screen's order counts and a future
/// "My Orders" list have something real to read from once that flow
/// exists.
class OrderService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _ordersRef =>
      _db.collection('orders');

  Future<String> placeOrder({
    required String itemName,
    required double amountInr,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('Must be logged in to place an order');
    final doc = await _ordersRef.add({
      'userId': uid,
      'itemName': itemName,
      'amountInr': amountInr,
      'status': OrderStatus.processing.name,
      'placedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Stream<List<JewelOrder>> watchMyOrders({OrderStatus? filterStatus}) {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    Query<Map<String, dynamic>> q = _ordersRef
        .where('userId', isEqualTo: uid)
        .orderBy('placedAt', descending: true);
    if (filterStatus != null) {
      q = q.where('status', isEqualTo: filterStatus.name);
    }
    return q.snapshots().map(
          (snap) => snap.docs.map(JewelOrder.fromDoc).toList(),
    );
  }

  Future<Map<OrderStatus, int>> getOrderCounts() async {
    final uid = _uid;
    if (uid == null) {
      return {for (final s in OrderStatus.values) s: 0};
    }
    final snap = await _ordersRef.where('userId', isEqualTo: uid).get();
    final counts = {for (final s in OrderStatus.values) s: 0};
    for (final doc in snap.docs) {
      final status = OrderStatus.values.firstWhere(
            (s) => s.name == doc.data()['status'],
        orElse: () => OrderStatus.processing,
      );
      counts[status] = (counts[status] ?? 0) + 1;
    }
    return counts;
  }
}