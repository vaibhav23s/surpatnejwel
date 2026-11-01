import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/rate_store.dart';
import '../services/sip_service.dart';

int _fails = 0;
DateTime? _blockedUntil;

/// Profile se: pehle SIP code poochho, sahi ho to uska poora hisab kholo.
Future<void> openMySip(BuildContext context) async {
  void snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  if (_blockedUntil != null && DateTime.now().isBefore(_blockedUntil!)) {
    snack('Bahut baar galat code daala. Thodi der baad try karein.');
    return;
  }
  final code = await showDialog<String>(context: context, builder: (_) => const _MySipCodeDialog());
  if (code == null || !context.mounted) return;

  SipPlan? plan;
  try {
    plan = await SipService().getPlan(code);
  } catch (e) {
    snack('Code check nahi ho paya: $e');
    return;
  }
  if (!context.mounted) return;
  if (plan == null) {
    _fails++;
    if (_fails >= 5) {
      _fails = 0;
      _blockedUntil = DateTime.now().add(const Duration(minutes: 5));
    }
    snack('Code galat hai');
    return;
  }
  _fails = 0;
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => MySipScreen(code: code)));
}

class _MySipCodeDialog extends StatefulWidget {
  const _MySipCodeDialog();

  @override
  State<_MySipCodeDialog> createState() => _MySipCodeDialogState();
}

class _MySipCodeDialogState extends State<_MySipCodeDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cream,
      title: Text('SIP Code daalein', style: AppText.heading.copyWith(color: AppColors.black, fontSize: 18)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Shop se mila 6 digit ka code', style: AppText.bodyMuted.copyWith(color: Colors.black54, fontSize: 12)),
          const SizedBox(height: 12),
          TextField(
            controller: _c,
            obscureText: true,
            autofocus: true,
            maxLength: 6,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 26, letterSpacing: 8, fontWeight: FontWeight.w700, color: AppColors.black),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.gold.withOpacity(0.5))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.gold, width: 1.4)),
            ),
            onSubmitted: (v) {
              if (v.trim().length == 6) Navigator.of(context).pop(v.trim());
            },
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.black54))),
        TextButton(
          onPressed: () {
            final v = _c.text.trim();
            if (v.length == 6) Navigator.of(context).pop(v);
          },
          child: const Text('Dekho', style: TextStyle(color: AppColors.goldDark, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class MySipScreen extends StatefulWidget {
  final String code;
  const MySipScreen({super.key, required this.code});

  @override
  State<MySipScreen> createState() => _MySipScreenState();
}

class _MySipScreenState extends State<MySipScreen> {
  final _service = SipService();
  final _rateStore = RateStore();
  late final Stream<SipPlan?> _planStream = _service.watchPlan(widget.code);
  StreamSubscription<DailyRates>? _ratesSub;
  DailyRates? _rates;

  @override
  void initState() {
    super.initState();
    _ratesSub = _rateStore.watchRates().listen((r) {
      if (mounted) setState(() => _rates = r);
    });
  }

  @override
  void dispose() {
    _ratesSub?.cancel();
    super.dispose();
  }

  /// 1 gram ka rate. Gold value = 1 gram ka rate. Silver value = 10 gram ka rate.
  double? _rate(SipPlan p) {
    if (_rates == null) return null;
    final r = p.isGold ? _rates!.gold10gInr : _rates!.silverKgInr / 10;
    return r > 0 ? r : null;
  }

  Widget _card(Widget child, {Color? border}) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: border ?? AppColors.gold.withOpacity(0.3)),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
    ),
    child: child,
  );

  Widget _kv(String l, String r, {Color? color, bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(l, style: AppText.bodyMuted.copyWith(color: Colors.black54, fontSize: 12.5))),
        const SizedBox(width: 8),
        Text(
          r,
          style: AppText.body.copyWith(
            color: color ?? AppColors.black,
            fontSize: bold ? 15 : 13,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.goldDark),
        title: Text('Mera SIP', style: AppText.heading.copyWith(color: AppColors.black, fontSize: 20)),
      ),
      body: StreamBuilder<SipPlan?>(
        stream: _planStream,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Load nahi ho paya: ${snap.error}', textAlign: TextAlign.center));
          }
          if (!snap.hasData && snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.gold));
          }
          final plan = snap.data;
          if (plan == null) return const Center(child: Text('SIP nahi mili'));

          final due = computeSipDue(plan, DateTime.now());
          final metal = plan.isGold ? 'Gold' : 'Silver';
          final digits = plan.isGold ? 4 : 3;
          final closed = plan.status == 'closed';
          final paidCount = plan.paidMonths;
          final remainingCount = kSipMonths - paidCount;
          final rate = _rate(plan);

          // --- status banner ---
          String statusTitle;
          String statusLine;
          Color statusColor;
          IconData statusIcon;
          if (closed) {
            statusTitle = 'SIP band hai';
            statusLine = 'Ye SIP band ho chuki hai. Zyada jaankari ke liye shop par sampark karein.';
            statusColor = Colors.redAccent;
            statusIcon = Icons.block;
          } else if (due.state == SipState.completed) {
            statusTitle = 'Congratulations! 🎉';
            statusLine = 'Aapka $kSipMonths mahine ka SIP poora ho gaya. Shop par aakar apna item collect karein.';
            statusColor = AppColors.goldDark;
            statusIcon = Icons.emoji_events_outlined;
          } else if (due.state == SipState.payable) {
            statusTitle = 'Kist ${due.installmentNo} bharni hai';
            statusLine = due.lateFee > 0
                ? 'Is mahine ki kist baaki hai. Late fee ₹${due.lateFee} lagegi.'
                : 'Is mahine ki kist baaki hai. 1 se $kSipLastFreeDay tarikh tak bina late fee ke bhar sakte hain.';
            statusColor = Colors.orange.shade800;
            statusIcon = Icons.schedule;
          } else {
            statusTitle = 'Sab theek hai';
            statusLine = 'Agli kist ${sipMonthLabel(due.dueMonth!)} ki 1 tarikh ko bharni hai.';
            statusColor = AppColors.success;
            statusIcon = Icons.check_circle_outline;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- status ---
                _card(
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 30),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(statusTitle,
                                style: AppText.heading.copyWith(color: AppColors.black, fontSize: 16.5)),
                            const SizedBox(height: 4),
                            Text(statusLine,
                                style: AppText.bodyMuted.copyWith(color: Colors.black54, fontSize: 12, height: 1.4)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  border: statusColor.withOpacity(0.5),
                ),

                // --- plan summary ---
                _card(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan.name, style: AppText.heading.copyWith(color: AppColors.black, fontSize: 18)),
                    const SizedBox(height: 8),
                    _kv('$metal SIP', '₹${plan.amount} / mahina'),
                    _kv('Shuruat', '1 ${sipMonthLabel(plan.startMonth)}'),
                    _kv('Aakhri kist', sipMonthLabel(plan.endMonth)),
                    _kv('Kul 12 mahine ka', '₹${plan.amount * kSipMonths}'),
                  ],
                )),

                // --- hisab ---
                _card(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MERA HISAB', style: AppText.goldLabel.copyWith(fontSize: 11, letterSpacing: 1.2)),
                    const SizedBox(height: 8),
                    _kv('Kist bhari', '$paidCount / $kSipMonths'),
                    _kv('Ab tak jama', '₹${plan.totalPaid.toStringAsFixed(0)}', color: AppColors.success, bold: true),
                    _kv('Baaki kist', closed ? '—' : '$remainingCount'),
                    _kv('Baaki raashi', closed ? '—' : '₹${plan.amount * remainingCount}',
                        color: Colors.orange.shade800, bold: true),
                    _kv('Late fee di', '₹${plan.totalLateFee.toStringAsFixed(0)}'),
                    const Divider(height: 18),
                    _kv('Jama $metal', '${plan.gramsTotal.toStringAsFixed(digits)} g', bold: true),
                    _kv(
                      'Aaj ke bhav se keemat',
                      rate == null ? '—' : '₹${(plan.gramsTotal * rate).toStringAsFixed(0)}',
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: paidCount / kSipMonths,
                        minHeight: 8,
                        backgroundColor: AppColors.cream,
                        valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('Late fee shop ka charge hai, usme $metal nahi milta. Keemat roz ke rate se badalti hai.',
                        style: AppText.bodyMuted.copyWith(color: Colors.black45, fontSize: 10.5, height: 1.4)),
                  ],
                )),

                // --- 12 months ---
                Text('Mahine ke hisab se kist',
                    style: AppText.body.copyWith(color: AppColors.black, fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 10),
                ...List.generate(kSipMonths, (i) {
                  final no = i + 1;
                  final month = plan.dueMonth(i);
                  final isPaid = no <= paidCount;
                  final isCurrent = !closed && due.state == SipState.payable && due.installmentNo == no;

                  Color c;
                  IconData icon;
                  String line2;
                  if (isPaid) {
                    c = AppColors.success;
                    icon = Icons.check_circle;
                    line2 = 'Jama ho gayi  •  ₹${plan.amount}';
                  } else if (closed) {
                    c = Colors.black26;
                    icon = Icons.block;
                    line2 = 'SIP band hone se nahi bhari';
                  } else if (isCurrent) {
                    c = Colors.orange.shade800;
                    icon = Icons.schedule;
                    line2 = 'Abhi bharni hai  •  ₹${plan.amount}${due.lateFee > 0 ? " + ₹${due.lateFee} late fee" : ""}';
                  } else {
                    c = Colors.black38;
                    icon = Icons.radio_button_unchecked;
                    line2 = 'Aage aayegi  •  ₹${plan.amount}';
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: c.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(icon, color: c, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Kist $no  •  ${sipMonthLabel(month)}',
                                  style: AppText.body.copyWith(color: AppColors.black, fontSize: 13, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(line2, style: AppText.bodyMuted.copyWith(color: c, fontSize: 11.5)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 10),
                Text(
                  'Kist bharne ke liye Investment → SIP → Get Start dabayein aur apna code daalein.',
                  style: AppText.bodyMuted.copyWith(color: Colors.black54, fontSize: 11, height: 1.4),
                ),
                const SizedBox(height: 6),
                Text(
                  'Yaad rakhein: SIP code sabse zaroori hai. Code gum hone par SIP cancel maani jayegi.',
                  style: AppText.bodyMuted.copyWith(color: Colors.black54, fontSize: 11, height: 1.4),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}