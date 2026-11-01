import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/girvi_service.dart';
import '../services/girvi_receipt_pdf.dart';
import '../utils/currency_format.dart';

/// Customer-facing "Girvi Section". The customer types the Girvi ID
/// printed on their receipt (e.g. GRV-2026-4821) and their bill —
/// item photo, live accrued interest, total outstanding, countdown,
/// payment history — opens right here. Loans already linked to their
/// account (if any) also show up automatically below.
class CustomerGirviScreen extends StatefulWidget {
  const CustomerGirviScreen({super.key});

  @override
  State<CustomerGirviScreen> createState() => _CustomerGirviScreenState();
}

class _CustomerGirviScreenState extends State<CustomerGirviScreen> {
  final _service = GirviService();
  final _idCtrl = TextEditingController();
  GirviLoan? _found;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _idCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final id = _idCtrl.text.trim();
    if (id.isEmpty) {
      setState(() => _error = 'Pehle apna Girvi ID daalo');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _found = null;
    });
    try {
      final loan = await _service.getLoanByReceiptNumber(id);
      setState(() {
        _found = loan;
        if (loan == null) _error = 'Ye Girvi ID nahi mila. Receipt par likha ID dobara check karo.';
      });
    } catch (_) {
      setState(() => _error = 'Bill load nahi ho paya. Internet check karo ya ID dobara dekho.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.goldDark),
        title: Text('Girvi Section', style: AppText.heading.copyWith(color: AppColors.black, fontSize: 19)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.gold.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('See your Girvi item', style: AppText.heading.copyWith(color: AppColors.black, fontSize: 18)),
                const SizedBox(height: 4),
                Text('Add your Girvi ID — receipt par likha hota hai (jaise GRV-2026-4821)',
                    style: AppText.bodyMuted.copyWith(color: Colors.black54, fontSize: 12)),
                const SizedBox(height: 14),
                TextField(
                  controller: _idCtrl,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(color: AppColors.black, fontSize: 14, letterSpacing: 0.5),
                  onSubmitted: (_) => _lookup(),
                  decoration: InputDecoration(
                    hintText: 'GRV-2026-XXXX',
                    hintStyle: const TextStyle(color: Colors.black38),
                    prefixIcon: const Icon(Icons.receipt_long_outlined, color: AppColors.goldDark, size: 20),
                    filled: true,
                    fillColor: AppColors.cream,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: AppColors.gold.withOpacity(0.4))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: AppColors.gold, width: 1.4)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: AppColors.gold.withOpacity(0.4))),
                  ),
                ),
                const SizedBox(height: 12),
                GoldButton(label: _loading ? 'Dhundh rahe hain...' : 'Mera Bill Dekho', onTap: _loading ? null : _lookup),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: TextStyle(color: Colors.red.shade600, fontSize: 12)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (_found != null) _GirviCard(key: ValueKey(_found!.id), loan: _found!),

          // Loans already linked to this account (admin linked it at billing time)
          if (uid != null)
            StreamBuilder<List<GirviLoan>>(
              stream: _service.watchLoansForCustomer(uid),
              builder: (context, snapshot) {
                final loans = (snapshot.data ?? [])
                    .where((l) => l.status == 'active' && l.id != _found?.id)
                    .toList();
                if (loans.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10, top: 4),
                      child: Text('Aapke account se jude Girvi items', style: AppText.body.copyWith(color: AppColors.black, fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                    ...loans.map((l) => _GirviCard(key: ValueKey(l.id), loan: l)),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _GirviCard extends StatefulWidget {
  final GirviLoan loan;
  const _GirviCard({super.key, required this.loan});

  @override
  State<_GirviCard> createState() => _GirviCardState();
}

class _GirviCardState extends State<_GirviCard> {
  Timer? _timer;
  late final Stream<List<GirviInterestPayment>> _paymentsStream =
      GirviService().watchPayments(widget.loan.id);

  @override
  void initState() {
    super.initState();
    // Ticks once a minute so "accrued interest" and the countdown
    // stay current without the customer needing to pull-to-refresh.
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loan = widget.loan;
    final interest = loan.accruedInterest();
    final total = loan.principalAmount + interest;
    final daysLeft = loan.daysRemaining;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (loan.itemPhotoUrl.isNotEmpty)
            Image.network(loan.itemPhotoUrl, height: 160, width: double.infinity, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(height: 160, color: AppColors.cream, child: const Icon(Icons.diamond_outlined, size: 40, color: AppColors.gold)))
          else
            Container(height: 100, color: AppColors.cream, child: const Icon(Icons.diamond_outlined, size: 36, color: AppColors.gold)),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(loan.receiptNumber, style: AppText.goldLabel.copyWith(fontSize: 11, fontWeight: FontWeight.w700)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: daysLeft < 0 ? Colors.red.withOpacity(0.12) : AppColors.gold.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        daysLeft < 0 ? '${-daysLeft} din late' : '$daysLeft din baaki',
                        style: TextStyle(color: daysLeft < 0 ? Colors.red : AppColors.goldDark, fontSize: 10.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('${loan.itemName} — ${loan.purity}', style: AppText.body.copyWith(color: AppColors.black, fontWeight: FontWeight.w700, fontSize: 15)),
                Text('Net Weight: ${loan.netWeightGrams} g', style: AppText.bodyMuted.copyWith(color: Colors.black54, fontSize: 11.5)),
                const SizedBox(height: 14),

                StreamBuilder<List<GirviInterestPayment>>(
                  stream: _paymentsStream,
                  builder: (context, snap) {
                    final paid = GirviService.sumPaid(snap.data ?? const []);
                    final outstanding = (total - paid).clamp(0, double.infinity).toDouble();
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.cream, borderRadius: BorderRadius.circular(14)),
                      child: Column(
                        children: [
                          _kv('Principal Borrowed', '₹${formatInr(loan.principalAmount)}'),
                          const SizedBox(height: 6),
                          _kv('Accrued Interest (aaj tak)', '₹${formatInr(interest)}'),
                          const SizedBox(height: 6),
                          _kv('Interest Jama Kiya', '₹${formatInr(paid)}'),
                          const Divider(height: 18),
                          _kv('Total Outstanding (aaj)', '₹${formatInr(outstanding)}', bold: true),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _kv('Shuru Date', '${loan.startDate.day}/${loan.startDate.month}/${loan.startDate.year}'),
                _kv('Chudwane ki akhri tareekh', '${loan.expectedEndDate.day}/${loan.expectedEndDate.month}/${loan.expectedEndDate.year}'),

                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () => GirviReceiptPdf.shareOrPrint(loan),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.gold.withOpacity(0.5)),
                    minimumSize: const Size(double.infinity, 44),
                  ),
                  icon: const Icon(Icons.download_outlined, color: AppColors.goldDark, size: 18),
                  label: const Text('Receipt Download Karo', style: TextStyle(color: AppColors.black)),
                ),

                const SizedBox(height: 14),
                Text('Interest Payment History', style: AppText.body.copyWith(color: AppColors.black, fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                StreamBuilder<List<GirviInterestPayment>>(
                  stream: _paymentsStream,
                  builder: (context, snapshot) {
                    final payments = snapshot.data ?? [];
                    if (payments.isEmpty) {
                      return Text('Abhi tak koi interest payment nahi hui.', style: AppText.bodyMuted.copyWith(color: Colors.black45, fontSize: 11.5));
                    }
                    return Column(
                      children: payments.map((p) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${p.paidAt.day}/${p.paidAt.month}/${p.paidAt.year}', style: AppText.bodyMuted.copyWith(color: Colors.black54, fontSize: 11.5)),
                              Text('₹${formatInr(p.amountPaid)}', style: AppText.body.copyWith(color: AppColors.black, fontSize: 12.5, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String l, String r, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(l, style: AppText.bodyMuted.copyWith(color: Colors.black54, fontSize: bold ? 12.5 : 11.5)),
        Text(r, style: AppText.body.copyWith(color: bold ? AppColors.goldDark : AppColors.black, fontSize: bold ? 15 : 12.5, fontWeight: FontWeight.w700)),
      ],
    );
  }
}