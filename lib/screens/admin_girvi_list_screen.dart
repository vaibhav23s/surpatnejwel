import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/girvi_service.dart';
import '../services/girvi_receipt_pdf.dart';
import '../utils/currency_format.dart';
import 'admin_create_girvi_screen.dart';

/// Admin-only: every Girvi loan — active, closed, auctioned. Tap a
/// loan to see full detail, record an interest payment, reprint the
/// receipt, or close/mark it settled.
class AdminGirviListScreen extends StatelessWidget {
  const AdminGirviListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = GirviService();

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.gold),
        title: Text('Girvi Bills', style: AppText.heading.copyWith(fontSize: 18)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.black,
        icon: const Icon(Icons.add),
        label: const Text('Naya Bill'),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminCreateGirviScreen())),
      ),
      body: StreamBuilder<List<GirviLoan>>(
        stream: service.watchAllLoans(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Load nahi ho paya. Firestore rules check karo.\n\n${snapshot.error}',
                    textAlign: TextAlign.center, style: AppText.bodyMuted.copyWith(fontSize: 12)),
              ),
            );
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.gold));
          final loans = snapshot.data!;
          if (loans.isEmpty) {
            return Center(child: Text('Abhi koi Girvi bill nahi hai.', style: AppText.bodyMuted.copyWith(fontSize: 13)));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            itemCount: loans.length,
            itemBuilder: (context, i) => _LoanCard(loan: loans[i]),
          );
        },
      ),
    );
  }
}

class _LoanCard extends StatelessWidget {
  final GirviLoan loan;
  const _LoanCard({required this.loan});

  @override
  Widget build(BuildContext context) {
    final interest = loan.accruedInterest();
    final total = loan.principalAmount + interest;
    final overdue = loan.daysRemaining < 0;

    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminGirviDetailScreen(loan: loan))),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.charcoal,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gold.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(loan.receiptNumber, style: AppText.goldLabel.copyWith(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
                _StatusBadge(status: loan.status, overdue: overdue),
              ],
            ),
            const SizedBox(height: 6),
            Text('${loan.customerName} — ${loan.customerMobile}', style: AppText.body.copyWith(fontSize: 14, fontWeight: FontWeight.w600)),
            Text('${loan.itemName} • ${loan.purity} • ${loan.netWeightGrams}g', style: AppText.bodyMuted.copyWith(fontSize: 11.5)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Principal: ₹${formatInr(loan.principalAmount)}', style: AppText.bodyMuted.copyWith(fontSize: 11.5)),
                Text('Total Due: ₹${formatInr(total)}', style: AppText.body.copyWith(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.gold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final bool overdue;
  const _StatusBadge({required this.status, required this.overdue});

  @override
  Widget build(BuildContext context) {
    Color c = AppColors.gold;
    String label = status.toUpperCase();
    if (status == 'closed') c = Colors.green;
    if (status == 'auctioned') c = Colors.redAccent;
    if (status == 'active' && overdue) {
      c = Colors.redAccent;
      label = 'OVERDUE';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: c.withOpacity(0.5))),
      child: Text(label, style: TextStyle(color: c, fontSize: 9.5, fontWeight: FontWeight.w700)),
    );
  }
}

/// Full detail for one loan — admin can record an interest payment,
/// reprint the receipt, or mark the loan closed/auctioned.
class AdminGirviDetailScreen extends StatefulWidget {
  final GirviLoan loan;
  const AdminGirviDetailScreen({super.key, required this.loan});

  @override
  State<AdminGirviDetailScreen> createState() => _AdminGirviDetailScreenState();
}

class _AdminGirviDetailScreenState extends State<AdminGirviDetailScreen> {
  final _service = GirviService();
  final _paymentCtrl = TextEditingController();
  bool _showKyc = false;

  // List se jo bill aaya wo adhura hai (private data nahi hota).
  // Yahan poora bill load hota hai: KYC number, photos aur signatures ke saath.
  late GirviLoan _loan = widget.loan;
  late final Stream<List<GirviInterestPayment>> _paymentsStream = _service.watchPayments(widget.loan.id);

  @override
  void initState() {
    super.initState();
    _service.getLoan(widget.loan.id).then((full) {
      if (mounted && full != null) setState(() => _loan = full);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _paymentCtrl.dispose();
    super.dispose();
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  /// 123456789012 -> XXXXXXXX9012 (only last 4 visible until admin taps the eye).
  String _maskKyc(String n) {
    final clean = n.replaceAll(' ', '');
    if (clean.length <= 4) return clean;
    return 'X' * (clean.length - 4) + clean.substring(clean.length - 4);
  }

  Future<void> _recordPayment() async {
    final amount = double.tryParse(_paymentCtrl.text.trim());
    if (amount == null || amount <= 0) {
      _snack('Sahi amount daalo');
      return;
    }
    try {
      await _service.recordInterestPayment(_loan.id, amountPaid: amount);
      _paymentCtrl.clear();
      if (mounted) _snack('Payment record ho gaya');
    } catch (e) {
      if (mounted) _snack('Record nahi hua: $e');
    }
  }

  Future<void> _confirmStatus(String status) async {
    final isAuction = status == 'auctioned';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.charcoal,
        title: Text(
          isAuction ? 'Nilaam mark karna hai?' : 'Bill band karna hai?',
          style: AppText.heading.copyWith(fontSize: 17),
        ),
        content: Text(
          isAuction
              ? '${_loan.receiptNumber} ko "Auctioned" mark kar dene par customer ko bill me nilaam dikhega. Pakka karna hai?'
              : '${_loan.receiptNumber} ko "Closed" mark kar dene par ye bill band maana jayega. Pakka karna hai?',
          style: AppText.bodyMuted.copyWith(fontSize: 12.5, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Nahi')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              isAuction ? 'Haan, nilaam' : 'Haan, band karo',
              style: TextStyle(color: isAuction ? Colors.redAccent : Colors.green.shade400),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.updateStatus(_loan.id, status);
      if (!mounted) return;
      _snack(isAuction ? 'Bill "Auctioned" mark ho gaya' : 'Bill band ho gaya');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) _snack('Badal nahi paya: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loan = _loan;
    final interest = loan.accruedInterest();
    final total = loan.principalAmount + interest;

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.gold),
        title: Text(loan.receiptNumber, style: AppText.heading.copyWith(fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.gold),
            onPressed: () => GirviReceiptPdf.shareOrPrint(loan),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PhotosRow(loan: loan),
            _DetailCard(title: 'Customer', rows: [
              ('Name', loan.customerName),
              ('Mobile', loan.customerMobile),
              ('KYC Type', loan.kycType),
            ]),
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
              decoration: BoxDecoration(
                color: AppColors.charcoal,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.gold.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  SizedBox(width: 120, child: Text('KYC Number', style: AppText.bodyMuted.copyWith(fontSize: 11.5))),
                  Expanded(
                    child: Text(
                      loan.kycNumber.isEmpty ? '—' : (_showKyc ? loan.kycNumber : _maskKyc(loan.kycNumber)),
                      style: AppText.body.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                    ),
                  ),
                  IconButton(
                    tooltip: _showKyc ? 'Chhupao' : 'Poora number dikhao',
                    icon: Icon(_showKyc ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.gold, size: 20),
                    onPressed: () => setState(() => _showKyc = !_showKyc),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _DetailCard(title: 'Item', rows: [
              ('Item', '${loan.itemName} (${loan.itemCategory})'),
              ('Purity', loan.purity),
              ('Weight', '${loan.grossWeightGrams}g gross / ${loan.netWeightGrams}g net'),
            ]),
            const SizedBox(height: 14),
            StreamBuilder<List<GirviInterestPayment>>(
              stream: _paymentsStream,
              builder: (context, snap) {
                final paid = GirviService.sumPaid(snap.data ?? const []);
                final outstanding = (total - paid).clamp(0, double.infinity).toDouble();
                return _DetailCard(title: 'Loan', rows: [
                  ('Principal', '₹${formatInr(loan.principalAmount)}'),
                  ('Interest Rate', '${loan.interestRatePercent}% / month'),
                  ('Accrued Interest', '₹${formatInr(interest)}'),
                  ('Interest Paid', '₹${formatInr(paid)}'),
                  ('Total Outstanding', '₹${formatInr(outstanding)}'),
                  ('Start Date', '${loan.startDate.day}/${loan.startDate.month}/${loan.startDate.year}'),
                  ('Days Remaining', '${loan.daysRemaining}'),
                  ('Status', loan.status),
                ]);
              },
            ),
            const SizedBox(height: 20),

            Text('Interest Payment Record Karo', style: AppText.body.copyWith(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: GoldTextField(hint: 'Amount Paid (₹)', icon: Icons.currency_rupee, controller: _paymentCtrl, keyboardType: TextInputType.number)),
                const SizedBox(width: 10),
                GoldButton(label: 'Add', onTap: _recordPayment, height: 48),
              ],
            ),
            const SizedBox(height: 20),

            Text('Payment History', style: AppText.body.copyWith(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 10),
            StreamBuilder<List<GirviInterestPayment>>(
              stream: _paymentsStream,
              builder: (context, snapshot) {
                final payments = snapshot.data ?? [];
                if (payments.isEmpty) return Text('Koi payment record nahi hai.', style: AppText.bodyMuted.copyWith(fontSize: 12));
                return Column(
                  children: payments.map((p) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.charcoal, borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${p.paidAt.day}/${p.paidAt.month}/${p.paidAt.year}', style: AppText.bodyMuted.copyWith(fontSize: 11.5)),
                          Text('₹${formatInr(p.amountPaid)}', style: AppText.body.copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.green.shade400)),
                    onPressed: () => _confirmStatus('closed'),
                    child: Text('Mark Closed', style: TextStyle(color: Colors.green.shade400)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                    onPressed: () => _confirmStatus('auctioned'),
                    child: const Text('Mark Auctioned', style: TextStyle(color: Colors.redAccent)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final String title;
  final List<(String, String)> rows;
  const _DetailCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.charcoal, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.gold.withOpacity(0.25))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.goldLabel.copyWith(fontSize: 11, letterSpacing: 1)),
          const SizedBox(height: 8),
          ...rows.map((r) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(width: 120, child: Text(r.$1, style: AppText.bodyMuted.copyWith(fontSize: 11.5))),
                Expanded(child: Text(r.$2, style: AppText.body.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600))),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

/// Document / customer / item photos captured while making the bill.
/// Tap any thumbnail to open it full-screen (pinch to zoom).
class _PhotosRow extends StatelessWidget {
  final GirviLoan loan;
  const _PhotosRow({required this.loan});

  @override
  Widget build(BuildContext context) {
    final photos = <(String, String)>[
      ('Customer', loan.customerPhotoUrl),
      ('ID Document', loan.kycDocUrl),
      ('Item', loan.itemPhotoUrl),
    ].where((p) => p.$2.isNotEmpty).toList();

    if (photos.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text('Is bill me koi photo save nahi hui.', style: AppText.bodyMuted.copyWith(fontSize: 11.5)),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: photos.map((p) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _PhotoThumb(label: p.$1, url: p.$2),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  final String label;
  final String url;
  const _PhotoThumb({required this.label, required this.url});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(12),
          child: InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)),
        ),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              url,
              height: 100,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 100,
                color: AppColors.charcoal,
                child: Icon(Icons.broken_image_outlined, color: AppColors.gold.withOpacity(0.5)),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: AppText.bodyMuted.copyWith(fontSize: 10.5)),
        ],
      ),
    );
  }
}