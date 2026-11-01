import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const List<int> kGoldSipAmounts = [500, 1000, 2000, 5000, 10000];
const List<int> kSilverSipAmounts = [200, 500, 1000, 2000, 5000];
const int kSipMonths = 12;
const int kSipLateFeeStep = 10;
const int kSipLastFreeDay = 3;

const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String sipMonthKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';
String sipMonthLabel(DateTime d) => '${_monthNames[d.month - 1]} ${d.year}';

class SipPlan {
  final String code;
  final String name;
  final String metal; // 'gold' | 'silver'
  final int amount;
  final DateTime startMonth;
  final DateTime createdAt;
  final String status; // 'active' | 'closed'
  final int paidMonths;
  final double gramsTotal;
  final double totalPaid;
  final double totalLateFee;

  const SipPlan({
    required this.code,
    required this.name,
    required this.metal,
    required this.amount,
    required this.startMonth,
    required this.createdAt,
    required this.status,
    required this.paidMonths,
    required this.gramsTotal,
    required this.totalPaid,
    required this.totalLateFee,
  });

  bool get isGold => metal == 'gold';
  DateTime dueMonth(int index) => DateTime(startMonth.year, startMonth.month + index, 1);
  DateTime get endMonth => dueMonth(kSipMonths - 1);

  factory SipPlan.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return SipPlan(
      code: doc.id,
      name: (d['name'] as String?) ?? '',
      metal: (d['metal'] as String?) ?? 'gold',
      amount: (d['amount'] as num?)?.toInt() ?? 0,
      startMonth: (d['startMonth'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: (d['status'] as String?) ?? 'active',
      paidMonths: (d['paidMonths'] as num?)?.toInt() ?? 0,
      gramsTotal: (d['gramsTotal'] as num?)?.toDouble() ?? 0,
      totalPaid: (d['totalPaid'] as num?)?.toDouble() ?? 0,
      totalLateFee: (d['totalLateFee'] as num?)?.toDouble() ?? 0,
    );
  }
}

enum SipState { closed, completed, notYet, payable }

class SipDue {
  final SipState state;
  final DateTime? dueMonth;
  final int installmentNo;
  final int lateFee;
  const SipDue(this.state, {this.dueMonth, this.installmentNo = 0, this.lateFee = 0});
}

/// 1-3 tarikh free. 4 tarikh se Rs10, aur har agle mahine +Rs10.
SipDue computeSipDue(SipPlan p, DateTime now) {
  if (p.status == 'closed') return const SipDue(SipState.closed);
  if (p.paidMonths >= kSipMonths) return const SipDue(SipState.completed);
  final due = p.dueMonth(p.paidMonths);
  final thisMonth = DateTime(now.year, now.month, 1);
  if (thisMonth.isBefore(due)) return SipDue(SipState.notYet, dueMonth: due);
  final monthsLate = (thisMonth.year - due.year) * 12 + (thisMonth.month - due.month);
  final int fee;
  if (monthsLate == 0) {
    fee = now.day <= kSipLastFreeDay ? 0 : kSipLateFeeStep;
  } else {
    fee = kSipLateFeeStep * (monthsLate + 1);
  }
  return SipDue(SipState.payable, dueMonth: due, installmentNo: p.paidMonths + 1, lateFee: fee);
}

class SipPayment {
  final String code;
  final String name;
  final int installmentNo;
  final String dueMonthKey;
  final int amount;
  final int lateFee;
  final double grams;
  final String paymentId;
  final DateTime paidAt;

  const SipPayment({
    required this.code,
    required this.name,
    required this.installmentNo,
    required this.dueMonthKey,
    required this.amount,
    required this.lateFee,
    required this.grams,
    required this.paymentId,
    required this.paidAt,
  });

  factory SipPayment.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return SipPayment(
      code: (d['code'] as String?) ?? '',
      name: (d['name'] as String?) ?? '',
      installmentNo: (d['installmentNo'] as num?)?.toInt() ?? 0,
      dueMonthKey: (d['dueMonthKey'] as String?) ?? '',
      amount: (d['amount'] as num?)?.toInt() ?? 0,
      lateFee: (d['lateFee'] as num?)?.toInt() ?? 0,
      grams: (d['grams'] as num?)?.toDouble() ?? 0,
      paymentId: (d['razorpayPaymentId'] as String?) ?? '',
      paidAt: (d['paidAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class SipService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _plans => _db.collection('sipAccounts');

  /// Admin: naya SIP banata hai, 6 digit unique code deta hai.
  Future<({String code, DateTime startMonth})> createPlan({
    required String name,
    required String mobile,
    required String aadhaar,
    required String metal,
    required int amount,
    required Uint8List photo,
    required Uint8List custSig,
    required Uint8List shopSig,
  }) async {
    final rnd = Random.secure();
    String code;
    do {
      code = (100000 + rnd.nextInt(900000)).toString();
    } while ((await _plans.doc(code).get()).exists);

    final now = DateTime.now();
    final start = DateTime(now.year, now.month + 1, 1);

    final batch = _db.batch();
    batch.set(_plans.doc(code), {
      'name': name,
      'metal': metal,
      'amount': amount,
      'startMonth': Timestamp.fromDate(start),
      'status': 'active',
      'paidMonths': 0,
      'gramsTotal': 0,
      'totalPaid': 0,
      'totalLateFee': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(_plans.doc(code).collection('private').doc('form'), {
      'mobile': mobile,
      'aadhaarLast4': aadhaar.substring(aadhaar.length - 4),
      'photo': base64Encode(photo),
      'custSig': base64Encode(custSig),
      'shopSig': base64Encode(shopSig),
    });
    await batch.commit();
    return (code: code, startMonth: start);
  }

  Future<SipPlan?> getPlan(String code) async {
    final snap = await _plans.doc(code).get();
    return snap.exists ? SipPlan.fromDoc(snap) : null;
  }

  Stream<SipPlan?> watchPlan(String code) =>
      _plans.doc(code).snapshots().map((s) => s.exists ? SipPlan.fromDoc(s) : null);

  Stream<List<SipPlan>> watchAllPlans() => _plans
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(SipPlan.fromDoc).toList());

  Stream<List<SipPayment>> watchPaymentsForMonth(String dueMonthKey) => _db
      .collection('sipPayments')
      .where('dueMonthKey', isEqualTo: dueMonthKey)
      .snapshots()
      .map((s) => s.docs.map(SipPayment.fromDoc).toList());

  Future<Map<String, dynamic>?> getPrivate(String code) async {
    final snap = await _plans.doc(code).collection('private').doc('form').get();
    return snap.data();
  }

  Future<void> closePlan(String code) async {
    await _plans.doc(code).update({'status': 'closed', 'closedAt': FieldValue.serverTimestamp()});
  }

  /// Razorpay success ke BAAD hi call karo.
  /// Razorpay success ke BAAD hi call karo.
  Future<void> recordPayment({
    required SipPlan plan,
    required SipDue due,
    required double ratePerGram,
    required String paymentId,
  }) async {
    final grams = plan.amount / ratePerGram;
    final batch = _db.batch();

    // Fixed ID: ek kist ka record sirf ek baar ban sakta hai
    batch.set(_db.collection('sipPayments').doc('${plan.code}_${due.installmentNo}'), {
      'code': plan.code,
      'name': plan.name,
      'metal': plan.metal,
      'installmentNo': due.installmentNo,
      'dueMonthKey': sipMonthKey(due.dueMonth!),
      'amount': plan.amount,
      'lateFee': due.lateFee,
      'grams': grams,
      'ratePerGram': ratePerGram,
      'razorpayPaymentId': paymentId,
      'paidByUid': FirebaseAuth.instance.currentUser?.uid ?? '',
      'paidAt': FieldValue.serverTimestamp(),
    });

    batch.update(_plans.doc(plan.code), {
      'paidMonths': FieldValue.increment(1),
      'gramsTotal': FieldValue.increment(grams),
      'totalPaid': FieldValue.increment(plan.amount),
      'totalLateFee': FieldValue.increment(due.lateFee),
      'lastPaidAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }
}