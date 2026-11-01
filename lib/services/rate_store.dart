import 'package:cloud_firestore/cloud_firestore.dart';

/// Today's gold/silver rate, set by the shop admin, synced via Firestore.
/// NOTE: purane naam (gold10gInr / silverKgInr) Firestore me waise hi hain,
/// par value ka matlab: gold10gInr = Gold 1 GRAM ka rate,
/// silverKgInr = Silver 10 GRAM ka rate (shop yahi type karti hai).
class DailyRates {
  final double gold10gInr;
  final double silverKgInr;
  final double? previousGold10gInr;
  final double? previousSilverKgInr;
  final DateTime updatedAt;

  const DailyRates({
    required this.gold10gInr,
    required this.silverKgInr,
    required this.updatedAt,
    this.previousGold10gInr,
    this.previousSilverKgInr,
  });
}

/// One saved rate-history entry.
class RateHistoryItem {
  final String id;
  final double gold10gInr;
  final double silverKgInr;
  final DateTime date;

  const RateHistoryItem({
    required this.id,
    required this.gold10gInr,
    required this.silverKgInr,
    required this.date,
  });

  factory RateHistoryItem.fromDocument(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data() ?? {};

    return RateHistoryItem(
      id: doc.id,
      gold10gInr: (data['gold10gInr'] as num?)?.toDouble() ?? 0,
      silverKgInr: (data['silverKgInr'] as num?)?.toDouble() ?? 0,
      date: (data['date'] as Timestamp?)?.toDate() ??
          (data['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.now(),
    );
  }
}

/// Reads/writes shop rates and their history.
class RateStore {
  final DocumentReference<Map<String, dynamic>> _doc =
  FirebaseFirestore.instance.collection('shop').doc('rates');

  CollectionReference<Map<String, dynamic>> get _historyCollection =>
      _doc.collection('history');

  static const double _defaultGold10g = 16900;
  static const double _defaultSilverKg = 2378;

  DailyRates _fromData(Map<String, dynamic>? data) {
    return DailyRates(
      gold10gInr:
      (data?['gold10gInr'] as num?)?.toDouble() ?? _defaultGold10g,
      silverKgInr:
      (data?['silverKgInr'] as num?)?.toDouble() ?? _defaultSilverKg,
      previousGold10gInr:
      (data?['previousGold10gInr'] as num?)?.toDouble(),
      previousSilverKgInr:
      (data?['previousSilverKgInr'] as num?)?.toDouble(),
      updatedAt: (data?['updatedAt'] as Timestamp?)?.toDate() ??
          DateTime.now(),
    );
  }

  Future<DailyRates> getRates() async {
    final snap = await _doc.get();
    return _fromData(snap.data());
  }

  /// Live current rate.
  Stream<DailyRates> watchRates() {
    return _doc.snapshots().map(
          (snap) => _fromData(snap.data()),
    );
  }

  /// Live rate history.
  Stream<List<RateHistoryItem>> watchRateHistory() {
    return _historyCollection
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
          .map(RateHistoryItem.fromDocument)
          .toList(),
    );
  }

  /// Save today's rate and create a history entry.
  Future<void> saveRates({
    required double gold10gInr,
    required double silverKgInr,
  }) async {
    final current = await _doc.get();
    final data = current.data();

    final prevGold = data?['gold10gInr'];
    final prevSilver = data?['silverKgInr'];

    // Save current/live rate.
    await _doc.set(
      {
        'gold10gInr': gold10gInr,
        'silverKgInr': silverKgInr,

        if (prevGold != null) 'previousGold10gInr': prevGold,
        if (prevSilver != null) 'previousSilverKgInr': prevSilver,

        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // Save a separate history entry.
    await _historyCollection.add(
      {
        'gold10gInr': gold10gInr,
        'silverKgInr': silverKgInr,
        'date': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      },
    );
  }
}