import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../theme/app_theme.dart';
import '../services/sip_service.dart';
import '../services/sip_pdf.dart';

class AdminSipReportScreen extends StatefulWidget {
  const AdminSipReportScreen({super.key});

  @override
  State<AdminSipReportScreen> createState() => _AdminSipReportScreenState();
}

class _AdminSipReportScreenState extends State<AdminSipReportScreen> {
  final _service = SipService();
  late final Stream<List<SipPlan>> _plansStream = _service.watchAllPlans();
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  late Stream<List<SipPayment>> _payStream = _service.watchPaymentsForMonth(sipMonthKey(_month));

  void _shift(int d) {
    setState(() {
      _month = DateTime(_month.year, _month.month + d, 1);
      _payStream = _service.watchPaymentsForMonth(sipMonthKey(_month));
    });
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _pdf(SipPlan p) async {
    try {
      final priv = await _service.getPrivate(p.code);
      if (priv == null) {
        _snack('Form data nahi mila');
        return;
      }
      final bytes = await buildSipFormPdf(SipFormData(
        code: p.code,
        name: p.name,
        mobile: (priv['mobile'] as String?) ?? '',
        aadhaar: 'XXXX XXXX ${priv['aadhaarLast4'] ?? ''}',
        metal: p.metal,
        amount: p.amount,
        startMonth: p.startMonth,
        createdAt: p.createdAt,
        photo: base64Decode(priv['photo'] as String),
        custSig: base64Decode(priv['custSig'] as String),
        shopSig: base64Decode(priv['shopSig'] as String),
      ));
      await Printing.sharePdf(bytes: bytes, filename: 'SIP-${p.code}.pdf');
    } catch (e) {
      _snack('PDF nahi bani: $e');
    }
  }

  Future<void> _close(SipPlan p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.charcoal,
        title: Text('SIP band karni hai?', style: AppText.heading.copyWith(fontSize: 17)),
        content: Text(
          '${p.name} (code ${p.code}) ki SIP band ho jayegi. Customer ab pay nahi kar payega. '
              'Ye wapas nahi hoti.',
          style: AppText.bodyMuted.copyWith(fontSize: 12.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Nahi')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Haan, band karo', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.closePlan(p.code);
      _snack('SIP band ho gayi');
    } catch (e) {
      _snack('Band nahi hui: $e');
    }
  }

  Widget _err(Object? e) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text('Load nahi ho paya. Firestore rules check karo.\n\n$e',
          textAlign: TextAlign.center, style: AppText.bodyMuted.copyWith(fontSize: 12)),
    ),
  );

  Widget _chip(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.charcoal,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.gold.withOpacity(0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.bodyMuted.copyWith(fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: AppText.body.copyWith(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.gold)),
      ],
    ),
  );

  Widget _row(SipPlan p, SipPayment? paid) {
    final closed = p.status == 'closed';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: AppColors.charcoal,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: (paid != null ? AppColors.success : Colors.orangeAccent).withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${p.name}  •  ${p.code}', style: AppText.body.copyWith(fontWeight: FontWeight.w600, fontSize: 13.5)),
                const SizedBox(height: 2),
                Text('${p.isGold ? "Gold" : "Silver"} ₹${p.amount}/mahina  •  ${p.paidMonths}/$kSipMonths kist${closed ? "  •  BAND" : ""}',
                    style: AppText.bodyMuted.copyWith(fontSize: 11)),
                const SizedBox(height: 4),
                Text(
                  paid != null
                      ? 'Jama: ₹${paid.amount}${paid.lateFee > 0 ? " + ₹${paid.lateFee} late" : ""}  •  ${paid.paidAt.day}/${paid.paidAt.month} ${paid.paidAt.hour.toString().padLeft(2, '0')}:${paid.paidAt.minute.toString().padLeft(2, '0')}'
                      : 'Baaki hai',
                  style: AppText.body.copyWith(fontSize: 12, color: paid != null ? AppColors.success : Colors.orangeAccent),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.gold, size: 20),
            onPressed: () => _pdf(p),
          ),
          if (!closed && p.paidMonths < kSipMonths)
            IconButton(
              tooltip: 'SIP band karo',
              icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 20),
              onPressed: () => _close(p),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.gold),
        title: Text('SIP Report', style: AppText.heading.copyWith(fontSize: 18)),
      ),
      body: StreamBuilder<List<SipPlan>>(
        stream: _plansStream,
        builder: (context, planSnap) {
          if (planSnap.hasError) return _err(planSnap.error);
          if (!planSnap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.gold));
          final plans = planSnap.data!;

          return StreamBuilder<List<SipPayment>>(
            stream: _payStream,
            builder: (context, paySnap) {
              if (paySnap.hasError) return _err(paySnap.error);
              final pays = paySnap.data ?? const <SipPayment>[];
              final paidBy = {for (final p in pays) p.code: p};

              final rows = <Widget>[];
              int pendingCount = 0;
              int pendingAmount = 0;
              for (final p in plans) {
                final paid = paidBy[p.code];
                final eligible = !_month.isBefore(p.startMonth) && !_month.isAfter(p.endMonth);
                final closed = p.status == 'closed';
                if (paid == null && (!eligible || closed)) continue;
                if (paid == null) {
                  pendingCount++;
                  pendingAmount += p.amount;
                }
                rows.add(_row(p, paid));
              }
              final sipSum = pays.fold<int>(0, (a, p) => a + p.amount);
              final feeSum = pays.fold<int>(0, (a, p) => a + p.lateFee);

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left, color: AppColors.gold)),
                      Text(sipMonthLabel(_month), style: AppText.heading.copyWith(fontSize: 18)),
                      IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right, color: AppColors.gold)),
                    ],
                  ),
                  Text('Is mahine ki kist ka hisab (kisne is mahine ki kist bhari)',
                      textAlign: TextAlign.center, style: AppText.bodyMuted.copyWith(fontSize: 11)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _chip('SIP jama', '₹$sipSum'),
                      _chip('Late fee', '₹$feeSum'),
                      _chip('Total aaya', '₹${sipSum + feeSum}'),
                      _chip('Bhar chuke', '${pays.length}'),
                      _chip('Baaki', '$pendingCount (₹$pendingAmount)'),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (rows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      child: Center(child: Text('Is mahine koi SIP nahi hai.', style: AppText.bodyMuted.copyWith(fontSize: 13))),
                    )
                  else
                    ...rows,
                ],
              );
            },
          );
        },
      ),
    );
  }
}