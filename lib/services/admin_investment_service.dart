import 'package:cloud_firestore/cloud_firestore.dart';
import 'investment_service.dart';

/// Admin-only: reads EVERY customer's investment transactions across
/// the whole app using a Firestore collectionGroup query (transactions
/// normally live under each user's own users/{uid}/investments —
/// collectionGroup looks across all of them at once). Only works if
/// firestore.rules grants admins read access to the 'investments'
/// collection group (see the wildcard rule added alongside this).
class AdminInvestmentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<InvestmentTransaction>> watchAllTransactions() {
    return _db
        .collectionGroup('investments')
        .orderBy('purchasedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(InvestmentTransaction.fromDoc).toList());
  }
}