import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// How much gold/silver a user currently owns, in grams. Running
/// totals kept on the user's own doc so reading "my holdings" is one
/// cheap read instead of summing every transaction every time.
class InvestmentHolding {
  final double goldGrams;
  final double silverGrams;
  const InvestmentHolding({required this.goldGrams, required this.silverGrams});

  factory InvestmentHolding.fromMap(Map<String, dynamic>? data) {
    return InvestmentHolding(
      goldGrams: (data?['investGoldGrams'] as num?)?.toDouble() ?? 0,
      silverGrams: (data?['investSilverGrams'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// One completed purchase — kept forever as a receipt / history entry.
class InvestmentTransaction {
  final String id;
  final String metal; // 'gold' or 'silver'
  final double amountInr;
  final double grams;
  final double ratePerGramInr;
  final String razorpayPaymentId;
  final DateTime purchasedAt;

  /// Only set for purchases of ₹2,00,000+ (the PAN-quoting threshold —
  /// see investment_screen.dart). Deliberately MASKED, never the full
  /// PAN — the full number lives only on the user's own profile doc.
  final String panMasked;

  /// Denormalized onto every transaction (not just looked up live) so
  /// the admin report can list "who bought what" in one query, without
  /// needing a separate read per user. See customerUid for the actual
  /// account link if you need it.
  final String customerUid;
  final String customerName;
  final String customerEmail;

  const InvestmentTransaction({
    required this.id,
    required this.metal,
    required this.amountInr,
    required this.grams,
    required this.ratePerGramInr,
    required this.razorpayPaymentId,
    required this.purchasedAt,
    this.panMasked = '',
    this.customerUid = '',
    this.customerName = '',
    this.customerEmail = '',
  });

  factory InvestmentTransaction.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return InvestmentTransaction(
      id: doc.id,
      metal: (data['metal'] as String?) ?? 'gold',
      amountInr: (data['amountInr'] as num?)?.toDouble() ?? 0,
      grams: (data['grams'] as num?)?.toDouble() ?? 0,
      ratePerGramInr: (data['ratePerGramInr'] as num?)?.toDouble() ?? 0,
      razorpayPaymentId: (data['razorpayPaymentId'] as String?) ?? '',
      purchasedAt: (data['purchasedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      panMasked: (data['panMasked'] as String?) ?? '',
      customerUid: (data['customerUid'] as String?) ?? '',
      customerName: (data['customerName'] as String?) ?? '',
      customerEmail: (data['customerEmail'] as String?) ?? '',
    );
  }
}

/// Records digital gold/silver purchases under the signed-in user's
/// own Firestore doc — users/{uid} for the running gram totals, and
/// users/{uid}/investments/{txnId} for the permanent purchase history.
/// Only ever called AFTER Razorpay confirms payment success.
class InvestmentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? get _userDoc =>
      _uid == null ? null : _db.collection('users').doc(_uid);

  Stream<InvestmentHolding> watchHoldings() {
    final doc = _userDoc;
    if (doc == null) return const Stream.empty();
    return doc.snapshots().map((snap) => InvestmentHolding.fromMap(snap.data()));
  }

  Stream<List<InvestmentTransaction>> watchTransactions() {
    final doc = _userDoc;
    if (doc == null) return const Stream.empty();
    return doc
        .collection('investments')
        .orderBy('purchasedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(InvestmentTransaction.fromDoc).toList());
  }

  /// Call this only after Razorpay's PAYMENT_SUCCESS callback fires.
  /// metal is 'gold' or 'silver'. Adds a permanent receipt and bumps
  /// the running gram total in one atomic write.
  Future<void> recordPurchase({
    required String metal,
    required double amountInr,
    required double grams,
    required double ratePerGramInr,
    required String razorpayPaymentId,
    String? panMasked,
  }) async {
    final doc = _userDoc;
    if (doc == null) throw StateError('Must be logged in to invest');

    // Pull current name/email to stamp onto the transaction so the
    // admin report can show "who" without a second read per row.
    final currentUser = _auth.currentUser;
    String customerName = currentUser?.displayName ?? '';
    if (customerName.isEmpty) {
      final profileSnap = await doc.get();
      customerName = (profileSnap.data()?['name'] as String?) ?? '';
    }

    final batch = _db.batch();
    final txnRef = doc.collection('investments').doc();
    batch.set(txnRef, {
      'metal': metal,
      'amountInr': amountInr,
      'grams': grams,
      'ratePerGramInr': ratePerGramInr,
      'razorpayPaymentId': razorpayPaymentId,
      if (panMasked != null && panMasked.isNotEmpty) 'panMasked': panMasked,
      'customerUid': currentUser?.uid ?? '',
      'customerName': customerName,
      'customerEmail': currentUser?.email ?? '',
      'purchasedAt': FieldValue.serverTimestamp(),
    });
    batch.set(doc, {
      metal == 'gold' ? 'investGoldGrams' : 'investSilverGrams':
      FieldValue.increment(grams),
    }, SetOptions(merge: true));

    await batch.commit();
  }
}