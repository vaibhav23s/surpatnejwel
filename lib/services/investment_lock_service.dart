import 'package:cloud_firestore/cloud_firestore.dart';

/// Admin-controlled on/off switches for the two Investment screen
/// sections. Stored at shop/investmentLocks so every customer's app
/// reflects the change live, same pattern as shop/rates and
/// shop/adBanner. Defaults to LOCKED (true) if the doc doesn't exist
/// yet, so a feature is never accidentally live before the admin
/// explicitly turns it on.
class InvestmentLocks {
  final bool sipLocked;
  final bool quickBuyLocked;

  const InvestmentLocks({required this.sipLocked, required this.quickBuyLocked});

  factory InvestmentLocks.fromData(Map<String, dynamic>? data) {
    return InvestmentLocks(
      sipLocked: (data?['sipLocked'] as bool?) ?? true,
      quickBuyLocked: (data?['quickBuyLocked'] as bool?) ?? true,
    );
  }
}

/// Write access restricted to admins only — enforced by firestore.rules
/// (see match /shop/investmentLocks), same as shop/rates.
class InvestmentLockService {
  final DocumentReference<Map<String, dynamic>> _doc =
  FirebaseFirestore.instance.collection('shop').doc('investmentLocks');

  Stream<InvestmentLocks> watchLocks() {
    return _doc.snapshots().map((snap) => InvestmentLocks.fromData(snap.data()));
  }

  Future<InvestmentLocks> getLocks() async {
    final snap = await _doc.get();
    return InvestmentLocks.fromData(snap.data());
  }

  Future<void> setSipLocked(bool locked) async {
    await _doc.set({'sipLocked': locked}, SetOptions(merge: true));
  }

  Future<void> setQuickBuyLocked(bool locked) async {
    await _doc.set({'quickBuyLocked': locked}, SetOptions(merge: true));
  }
}