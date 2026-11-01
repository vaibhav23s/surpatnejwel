import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// One "Girvi" (pawn) loan — item kept as collateral against a
/// principal amount at a fixed monthly interest rate.
///
/// Data do jagah rehta hai:
///  * girviLoans/{id}               -> customer ko dikhne wala hissa
///  * girviLoans/{id}/private/data  -> KYC number, photos, signatures (sirf admin)
class GirviLoan {
  final String id;
  final String receiptNumber;

  // Customer + KYC
  final String? customerUid; // linked app account, if the customer has one
  final String customerName;
  final String customerMobile;
  final String kycType; // Aadhaar Card / PAN Card / Voter ID / Driving License

  /// Admin ke liye poora number. Customer ke liye sirf masked (XXXXXXXX9012).
  final String kycNumber;
  final String kycDocUrl; // sirf admin
  final String customerPhotoUrl; // sirf admin

  // Item (vastu)
  final String itemName;
  final String itemCategory;
  final String purity; // 18K / 22K / 24K / Chandi %
  final double grossWeightGrams;
  final double netWeightGrams;
  final String itemPhotoUrl;

  // Loan terms
  final double principalAmount;
  final String paymentMode; // Cash / UPI / Bank Transfer
  final double interestRatePercent; // per month
  final DateTime startDate;
  final int tenureDays;
  final String nomineeName;
  final String nomineePhone;
  final bool termsAccepted;

  final String status; // active / closed / auctioned
  final DateTime createdAt;
  final String createdByAdminUid;

  /// Customer's on-screen signature (PNG, base64). Sirf admin.
  final String customerSignatureB64;

  /// Shop's own on-screen signature, optional. Sirf admin.
  final String adminSignatureB64;

  const GirviLoan({
    required this.id,
    required this.receiptNumber,
    this.customerUid,
    required this.customerName,
    required this.customerMobile,
    required this.kycType,
    required this.kycNumber,
    required this.kycDocUrl,
    required this.customerPhotoUrl,
    required this.itemName,
    required this.itemCategory,
    required this.purity,
    required this.grossWeightGrams,
    required this.netWeightGrams,
    required this.itemPhotoUrl,
    required this.principalAmount,
    required this.paymentMode,
    required this.interestRatePercent,
    required this.startDate,
    required this.tenureDays,
    required this.nomineeName,
    required this.nomineePhone,
    required this.termsAccepted,
    required this.status,
    required this.createdAt,
    required this.createdByAdminUid,
    this.customerSignatureB64 = '',
    this.adminSignatureB64 = '',
  });

  DateTime get expectedEndDate => startDate.add(Duration(days: tenureDays));
  int get daysRemaining => expectedEndDate.difference(DateTime.now()).inDays;
  int get daysElapsed => DateTime.now().difference(startDate).inDays.clamp(0, 1 << 30);

  /// 123456789012 -> XXXXXXXX9012 (pehle se masked ho to wahi rehta hai).
  String get kycMasked {
    final clean = kycNumber.replaceAll(' ', '');
    if (clean.length <= 4) return clean;
    return 'X' * (clean.length - 4) + clean.substring(clean.length - 4);
  }

  /// Simple interest, prorated daily off a monthly rate — standard
  /// pawn-shop convention. Accrued = principal * rate% * (days/30).
  double accruedInterest({DateTime? asOf}) {
    final days = (asOf ?? DateTime.now()).difference(startDate).inDays.clamp(0, 1 << 30);
    return principalAmount * (interestRatePercent / 100) * (days / 30.0);
  }

  /// [privateData] admin ke liye girviLoans/{id}/private/data ka data.
  /// Purane bills (jo abhi alag nahi kiye gaye) ke fields main doc se bhi padh liye jate hain.
  factory GirviLoan.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc, {
        Map<String, dynamic>? privateData,
      }) {
    final d = doc.data()!;
    final p = privateData ?? const <String, dynamic>{};

    String priv(String key) => (p[key] as String?) ?? (d[key] as String?) ?? '';

    return GirviLoan(
      id: doc.id,
      receiptNumber: (d['receiptNumber'] as String?) ?? '',
      customerUid: d['customerUid'] as String?,
      customerName: (d['customerName'] as String?) ?? '',
      customerMobile: (d['customerMobile'] as String?) ?? '',
      kycType: (d['kycType'] as String?) ?? '',
      kycNumber: (p['kycNumber'] as String?) ??
          (d['kycNumber'] as String?) ??
          (d['kycMasked'] as String?) ??
          '',
      kycDocUrl: priv('kycDocUrl'),
      customerPhotoUrl: priv('customerPhotoUrl'),
      itemName: (d['itemName'] as String?) ?? '',
      itemCategory: (d['itemCategory'] as String?) ?? '',
      purity: (d['purity'] as String?) ?? '',
      grossWeightGrams: (d['grossWeightGrams'] as num?)?.toDouble() ?? 0,
      netWeightGrams: (d['netWeightGrams'] as num?)?.toDouble() ?? 0,
      itemPhotoUrl: (d['itemPhotoUrl'] as String?) ?? '',
      principalAmount: (d['principalAmount'] as num?)?.toDouble() ?? 0,
      paymentMode: (d['paymentMode'] as String?) ?? 'Cash',
      interestRatePercent: (d['interestRatePercent'] as num?)?.toDouble() ?? 0,
      startDate: (d['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      tenureDays: (d['tenureDays'] as num?)?.toInt() ?? 30,
      nomineeName: (d['nomineeName'] as String?) ?? '',
      nomineePhone: (d['nomineePhone'] as String?) ?? '',
      termsAccepted: (d['termsAccepted'] as bool?) ?? false,
      status: (d['status'] as String?) ?? 'active',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdByAdminUid: (d['createdByAdminUid'] as String?) ?? '',
      customerSignatureB64: priv('customerSignatureB64'),
      adminSignatureB64: priv('adminSignatureB64'),
    );
  }

  /// Main doc: jo customer ko dikh sakta hai.
  Map<String, dynamic> toPublicMap() {
    return {
      'receiptNumber': receiptNumber,
      if (customerUid != null) 'customerUid': customerUid,
      'customerName': customerName,
      'customerMobile': customerMobile,
      'kycType': kycType,
      'kycMasked': kycMasked,
      'itemName': itemName,
      'itemCategory': itemCategory,
      'purity': purity,
      'grossWeightGrams': grossWeightGrams,
      'netWeightGrams': netWeightGrams,
      'itemPhotoUrl': itemPhotoUrl,
      'principalAmount': principalAmount,
      'paymentMode': paymentMode,
      'interestRatePercent': interestRatePercent,
      'startDate': Timestamp.fromDate(startDate),
      'tenureDays': tenureDays,
      'nomineeName': nomineeName,
      'nomineePhone': nomineePhone,
      'termsAccepted': termsAccepted,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdByAdminUid': createdByAdminUid,
    };
  }

  /// private/data doc: sirf admin padh sakta hai.
  Map<String, dynamic> toPrivateMap() {
    return {
      'kycNumber': kycNumber,
      'kycDocUrl': kycDocUrl,
      'customerPhotoUrl': customerPhotoUrl,
      if (customerSignatureB64.isNotEmpty) 'customerSignatureB64': customerSignatureB64,
      if (adminSignatureB64.isNotEmpty) 'adminSignatureB64': adminSignatureB64,
    };
  }
}

/// One interest payment made against a loan (partial or full).
class GirviInterestPayment {
  final String id;
  final double amountPaid;
  final double balanceAfter;
  final DateTime paidAt;

  const GirviInterestPayment({
    required this.id,
    required this.amountPaid,
    required this.balanceAfter,
    required this.paidAt,
  });

  factory GirviInterestPayment.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return GirviInterestPayment(
      id: doc.id,
      amountPaid: (d['amountPaid'] as num?)?.toDouble() ?? 0,
      balanceAfter: (d['balanceAfter'] as num?)?.toDouble() ?? 0,
      paidAt: (d['paidAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Firestore-backed CRUD for Girvi loans.
class GirviService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _loansRef => _db.collection('girviLoans');

  DocumentReference<Map<String, dynamic>> _privateRef(String loanId) =>
      _loansRef.doc(loanId).collection('private').doc('data');

  // 0, O, 1, I jaise confusing akshar nahi rakhe, taaki receipt padhna aasan ho.
  static const String _idChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// GRV-2026-K7M2Q9XA: saal + 8 random akshar (lagbhag 1 lakh crore se
  /// zyada combination), isliye koi andaza lagake dusre ka bill nahi khol sakta.
  String generateReceiptNumber() {
    final year = DateTime.now().year;
    final rnd = Random.secure();
    final code = List.generate(8, (_) => _idChars[rnd.nextInt(_idChars.length)]).join();
    return 'GRV-$year-$code';
  }

  /// Document ID == receipt number. Do doc ek saath likhe jate hain.
  Future<String> createLoan(GirviLoan loan) async {
    final uid = _auth.currentUser?.uid ?? '';
    final ref = _loansRef.doc(loan.receiptNumber);

    if ((await ref.get()).exists) {
      throw StateError('Ye bill ID pehle se maujood hai. Dobara try karo.');
    }

    final batch = _db.batch();
    batch.set(ref, loan.toPublicMap()..['createdByAdminUid'] = uid);
    batch.set(_privateRef(loan.receiptNumber), loan.toPrivateMap());
    await batch.commit();
    return loan.receiptNumber;
  }

  /// Customer-side lookup by the Girvi ID printed on their receipt.
  /// Sirf main doc padhta hai (private nahi).
  Future<GirviLoan?> getLoanByReceiptNumber(String receiptNumber) async {
    final id = receiptNumber.trim().toUpperCase();
    if (id.isEmpty) return null;
    final doc = await _loansRef.doc(id).get();
    return doc.exists ? GirviLoan.fromDoc(doc) : null;
  }

  Stream<List<GirviLoan>> watchAllLoans() {
    return _loansRef.orderBy('createdAt', descending: true).snapshots().map(
          (snap) => snap.docs.map(GirviLoan.fromDoc).toList(),
    );
  }

  /// Loans linked to a specific customer account — used by the
  /// customer-facing "Girvi Section" in their profile.
  Stream<List<GirviLoan>> watchLoansForCustomer(String uid) {
    return _loansRef
        .where('customerUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(GirviLoan.fromDoc).toList());
  }

  /// Poora bill. Admin ho to private data bhi judta hai; customer ho to
  /// private padhne ki permission nahi hoti, isliye sirf main doc milta hai.
  Future<GirviLoan?> getLoan(String loanId) async {
    final doc = await _loansRef.doc(loanId).get();
    if (!doc.exists) return null;

    Map<String, dynamic>? priv;
    try {
      priv = (await _privateRef(loanId).get()).data();
    } catch (_) {
      priv = null;
    }
    return GirviLoan.fromDoc(doc, privateData: priv);
  }

  Future<void> updateStatus(String loanId, String status) async {
    await _loansRef.doc(loanId).update({'status': status});
  }

  Stream<List<GirviInterestPayment>> watchPayments(String loanId) {
    return _loansRef
        .doc(loanId)
        .collection('interestPayments')
        .orderBy('paidAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(GirviInterestPayment.fromDoc).toList());
  }

  /// Ab tak ki saari interest payments ka jod.
  static double sumPaid(List<GirviInterestPayment> list) =>
      list.fold<double>(0, (a, p) => a + p.amountPaid);

  /// Payment likhta hai. balanceAfter khud nikalta hai:
  /// (ab tak ka interest) - (pehle ki payments + ye payment).
  Future<void> recordInterestPayment(
      String loanId, {
        required double amountPaid,
      }) async {
    final loanDoc = await _loansRef.doc(loanId).get();
    if (!loanDoc.exists) throw StateError('Bill nahi mila');
    final loan = GirviLoan.fromDoc(loanDoc);
    final prev = await _loansRef.doc(loanId).collection('interestPayments').get();
    final paidBefore = prev.docs.fold<double>(
        0, (a, d) => a + ((d.data()['amountPaid'] as num?)?.toDouble() ?? 0));
    final balanceAfter =
        (loan.accruedInterest() - paidBefore - amountPaid).clamp(0, double.infinity).toDouble();
    await _loansRef.doc(loanId).collection('interestPayments').add({
      'amountPaid': amountPaid,
      'balanceAfter': balanceAfter,
      'paidAt': FieldValue.serverTimestamp(),
    });
  }
}