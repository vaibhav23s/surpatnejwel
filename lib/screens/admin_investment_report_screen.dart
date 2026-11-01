import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/admin_investment_service.dart';
import '../services/investment_service.dart';
import '../utils/currency_format.dart';

/// Admin-only: every customer's investment purchase, in one table —
/// who paid, how much, which metal, what date. Admin-only, reachable
/// from the drawer (see rashifal_drawer.dart).
class AdminInvestmentReportScreen extends StatelessWidget {
  const AdminInvestmentReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = AdminInvestmentService();

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.gold),
        title: Text('Investment Report', style: AppText.heading.copyWith(fontSize: 18)),
      ),
      body: StreamBuilder<List<InvestmentTransaction>>(
        stream: service.watchAllTransactions(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Load nahi ho paya. Firestore rules me collectionGroup "investments" ka admin-read rule check karo.\n\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: AppText.bodyMuted.copyWith(fontSize: 12),
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.gold));
          }

          final txns = snapshot.data!;
          if (txns.isEmpty) {
            return Center(
              child: Text('Abhi tak koi investment purchase nahi hui.', style: AppText.bodyMuted.copyWith(fontSize: 13)),
            );
          }

          final totalAmount = txns.fold<double>(0, (a, t) => a + t.amountInr);
          final totalGold = txns.where((t) => t.metal == 'gold').fold<double>(0, (a, t) => a + t.grams);
          final totalSilver = txns.where((t) => t.metal == 'silver').fold<double>(0, (a, t) => a + t.grams);
          final uniqueCustomers = txns.map((t) => t.customerUid).toSet().length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _StatChip(label: 'Total Collected', value: '₹${formatInr(totalAmount)}'),
                    _StatChip(label: 'Transactions', value: '${txns.length}'),
                    _StatChip(label: 'Customers', value: '$uniqueCustomers'),
                    _StatChip(label: 'Gold Sold', value: '${totalGold.toStringAsFixed(3)} g'),
                    _StatChip(label: 'Silver Sold', value: '${totalSilver.toStringAsFixed(3)} g'),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(AppColors.charcoal),
                        dataRowColor: WidgetStateProperty.all(AppColors.charcoal.withOpacity(0.5)),
                        border: TableBorder.all(color: AppColors.gold.withOpacity(0.15)),
                        columns: const [
                          DataColumn(label: _Head('Date')),
                          DataColumn(label: _Head('Name')),
                          DataColumn(label: _Head('Email')),
                          DataColumn(label: _Head('Metal')),
                          DataColumn(label: _Head('Amount'), numeric: true),
                          DataColumn(label: _Head('Grams'), numeric: true),
                          DataColumn(label: _Head('Rate/g'), numeric: true),
                          DataColumn(label: _Head('Payment ID')),
                        ],
                        rows: txns.map((t) {
                          return DataRow(cells: [
                            DataCell(_Cell('${t.purchasedAt.day}/${t.purchasedAt.month}/${t.purchasedAt.year}\n${t.purchasedAt.hour.toString().padLeft(2, '0')}:${t.purchasedAt.minute.toString().padLeft(2, '0')}')),
                            DataCell(_Cell(t.customerName.isEmpty ? '—' : t.customerName)),
                            DataCell(_Cell(t.customerEmail.isEmpty ? '—' : t.customerEmail)),
                            DataCell(_Cell(t.metal == 'gold' ? 'Gold' : 'Silver')),
                            DataCell(_Cell('₹${formatInr(t.amountInr)}')),
                            DataCell(_Cell(t.grams.toStringAsFixed(4))),
                            DataCell(_Cell('₹${t.ratePerGramInr.toStringAsFixed(2)}')),
                            DataCell(_Cell(t.razorpayPaymentId.isEmpty ? '—' : t.razorpayPaymentId, mono: true)),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
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
  }
}

class _Head extends StatelessWidget {
  final String text;
  const _Head(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppText.goldLabel.copyWith(fontSize: 12, fontWeight: FontWeight.w700));
  }
}

class _Cell extends StatelessWidget {
  final String text;
  final bool mono;
  const _Cell(this.text, {this.mono = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppText.body.copyWith(
        fontSize: 11.5,
        fontFamily: mono ? 'monospace' : null,
      ),
    );
  }
}