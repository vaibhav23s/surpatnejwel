import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/rate_store.dart';
import '../services/sip_service.dart';
import '../utils/app_errors.dart';
import '../widgets/state_views.dart';
int _codeFails = 0;
DateTime? _codeBlockedUntil;

/// "Get Start" dabane par: pehle code poochho, sahi ho to SIP screen kholo.
Future<void> openSipWithCode(BuildContext context, String razorpayKey) async {
  void snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  if (_codeBlockedUntil != null && DateTime.now().isBefore(_codeBlockedUntil!)) {
    snack('Bahut baar galat code daala. Thodi der baad try karein.');
    return;
  }
  final code = await showDialog<String>(context: context, builder: (_) => const _CodeDialog());
  if (code == null || !context.mounted) return;
  SipPlan? plan;
  try {
    plan = await Net.withTimeout(SipService().getPlan(code), const Duration(seconds: 15));
  } catch (e) {
    snack(AppErrors.message(e));
    return;
  }
  if (!context.mounted) return;
  if (plan == null) {
    _codeFails++;
    if (_codeFails >= 5) {
      _codeFails = 0;
      _codeBlockedUntil = DateTime.now().add(const Duration(minutes: 5));
    }
    snack('Code galat hai');
    return;
  }
  _codeFails = 0;
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => SipPaymentScreen(code: code, razorpayKey: razorpayKey)),
  );
}

class _CodeDialog extends StatefulWidget {
  const _CodeDialog();

  @override
  State<_CodeDialog> createState() => _CodeDialogState();
}

class _CodeDialogState extends State<_CodeDialog> {
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
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.gold.withOpacity(0.5))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.gold, width: 1.4)),
            ),
            onSubmitted: (v) {
              if (v.trim().length == 6) Navigator.of(context).pop(v.trim());
            },
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel', style: TextStyle(color: Colors.black54))),
        TextButton(
          onPressed: () {
            final v = _c.text.trim();
            if (v.length == 6) Navigator.of(context).pop(v);
          },
          child: const Text('Aage badho', style: TextStyle(color: AppColors.goldDark, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class SipPaymentScreen extends StatefulWidget {
  final String code;
  final String razorpayKey;
  const SipPaymentScreen({super.key, required this.code, required this.razorpayKey});

  @override
  State<SipPaymentScreen> createState() => _SipPaymentScreenState();
}

class _SipPaymentScreenState extends State<SipPaymentScreen> {
  final _service = SipService();
  final _rateStore = RateStore();
  final _razorpay = Razorpay();
  late final Stream<SipPlan?> _planStream = _service.watchPlan(widget.code);
  StreamSubscription<DailyRates>? _ratesSub;
  DailyRates? _rates;
  bool _paying = false;

  SipPlan? _pPlan;
  SipDue? _pDue;
  double? _pRate;

  @override
  void initState() {
    super.initState();
    _ratesSub = _rateStore.watchRates().listen((r) {
      if (mounted) setState(() => _rates = r);
    });
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onWallet);
  }

  @override
  void dispose() {
    _ratesSub?.cancel();
    _razorpay.clear();
    super.dispose();
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  double? _rate(SipPlan p) {
    if (_rates == null) return null;
    // gold value = 1 gram ka rate, silver value = 10 gram ka rate
    final r = p.isGold ? _rates!.gold10gInr : _rates!.silverKgInr / 10;
    return r > 0 ? r : null;
  }
  Future<void> _pay(SipPlan plan, SipDue due) async {
    if (_paying) return;
    final rate = _rate(plan);
    if (rate == null) {
      _snack('Live rate is still loading. Please wait a moment and try again.');
      return;
    }
    if (widget.razorpayKey.contains('REPLACE_ME')) {
      _snack('Payments are not available right now. Please contact the shop.');
      return;
    }

    setState(() => _paying = true);
    if (!await Net.isOnline()) {
      if (mounted) setState(() => _paying = false);
      _snack(AppErrors.noInternet);
      return;
    }

    _pPlan = plan;
    _pDue = due;
    _pRate = rate;
    final total = plan.amount + due.lateFee;
    final options = {
      'key': widget.razorpayKey,
      'amount': total * 100,
      'name': 'Surpatne Jewellers',
      'description': 'SIP instalment ${due.installmentNo}/$kSipMonths (${plan.code})',
      'prefill': {'contact': '', 'email': FirebaseAuth.instance.currentUser?.email ?? ''},
      'theme': {'color': '#D4AF37'},
    };
    try {
      _razorpay.open(options);
    } catch (e) {
      if (mounted) setState(() => _paying = false);
      _snack(AppErrors.message(e));
    }
  }

  Future<void> _onSuccess(PaymentSuccessResponse r) async {
    final plan = _pPlan;
    final due = _pDue;
    final rate = _pRate;
    final paymentId = r.paymentId ?? '';
    final total = (plan != null && due != null) ? plan.amount + due.lateFee : null;

    try {
      if (plan != null && due != null && rate != null) {
        await Net.withTimeout(
          _service.recordPayment(plan: plan, due: due, ratePerGram: rate, paymentId: paymentId),
          const Duration(seconds: 25),
        );
      }
      _snack('Payment successful. Your instalment has been recorded.');
    } catch (e) {
      AppErrors.log(e);
      if (mounted) {
        await showPaidNotSavedDialog(
          context,
          paymentId: paymentId,
          amount: total,
          mayAutoUpdate: e is TimeoutException,
        );
      }
    } finally {
      if (mounted) setState(() => _paying = false);
      _pPlan = null;
      _pDue = null;
      _pRate = null;
    }
  }

  void _onError(PaymentFailureResponse r) {
    if (!mounted) return;
    setState(() => _paying = false);
    _snack(AppErrors.razorpay(r));
  }

  void _onWallet(ExternalWalletResponse r) {
    if (!mounted) return;
    setState(() => _paying = false);
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

  Widget _kv(String l, String r, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(l, style: AppText.bodyMuted.copyWith(color: Colors.black54, fontSize: 12.5)),
        Text(r, style: AppText.body.copyWith(color: AppColors.black, fontSize: bold ? 15 : 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
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
        title: Text('Meri SIP', style: AppText.heading.copyWith(color: AppColors.black, fontSize: 20)),
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

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _card(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan.name, style: AppText.heading.copyWith(color: AppColors.black, fontSize: 18)),
                    const SizedBox(height: 8),
                    _kv('Metal', metal),
                    _kv('Monthly SIP', '₹${plan.amount}'),
                    _kv('Kist bhari', '${plan.paidMonths} / $kSipMonths'),
                    _kv('Ab tak jama $metal', '${plan.gramsTotal.toStringAsFixed(4)} g'),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: plan.paidMonths / kSipMonths,
                        minHeight: 8,
                        backgroundColor: AppColors.cream,
                        valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                      ),
                    ),
                  ],
                )),

                if (due.state == SipState.completed)
                  _card(
                    Column(
                      children: [
                        const Icon(Icons.emoji_events_outlined, color: AppColors.goldDark, size: 46),
                        const SizedBox(height: 10),
                        Text('Congratulations! 🎉', style: AppText.heading.copyWith(color: AppColors.black, fontSize: 21)),
                        const SizedBox(height: 8),
                        Text(
                          'Aapka $kSipMonths mahine ka SIP poora ho gaya hai.\nKripya shop par aakar apna item collect karein.',
                          textAlign: TextAlign.center,
                          style: AppText.bodyMuted.copyWith(color: Colors.black87, fontSize: 13, height: 1.5),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Item us din ke bhav par milega, aur majuri (making charges) par 50% chhoot.',
                          textAlign: TextAlign.center,
                          style: AppText.bodyMuted.copyWith(color: Colors.black54, fontSize: 11.5),
                        ),
                      ],
                    ),
                    border: AppColors.gold,
                  ),

                if (due.state == SipState.closed)
                  _card(Text(
                    'Ye SIP band ho chuki hai. Zyada jaankari ke liye shop par sampark karein.',
                    style: AppText.bodyMuted.copyWith(color: Colors.black87, fontSize: 13),
                  )),

                if (due.state == SipState.notYet)
                  _card(Text(
                    'Agli kist ${sipMonthLabel(due.dueMonth!)} ki 1 tarikh se bhar sakte hain.',
                    style: AppText.bodyMuted.copyWith(color: Colors.black87, fontSize: 13),
                  )),

                if (due.state == SipState.payable) ...[
                  _card(Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Kist ${due.installmentNo} / $kSipMonths  •  ${sipMonthLabel(due.dueMonth!)}',
                          style: AppText.goldLabel.copyWith(fontSize: 12.5)),
                      const SizedBox(height: 8),
                      _kv('SIP amount', '₹${plan.amount}'),
                      if (due.lateFee > 0) _kv('Late fee', '₹${due.lateFee}'),
                      const Divider(height: 20),
                      _kv('Total bharna hai', '₹${plan.amount + due.lateFee}', bold: true),
                      const SizedBox(height: 6),
                      Text(
                        _rate(plan) == null
                            ? 'Rate load ho raha hai…'
                            : 'Aaj ke rate pe lagbhag ${(plan.amount / _rate(plan)!).toStringAsFixed(4)} g $metal milega.',
                        style: AppText.bodyMuted.copyWith(color: Colors.black54, fontSize: 11.5),
                      ),
                      if (due.lateFee > 0) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Late fee shop ka charge hai (1-3 tarikh ke baad ₹10, har mahine ₹10 badhti hai). Isme $metal nahi milta.',
                          style: AppText.bodyMuted.copyWith(color: Colors.red.shade700, fontSize: 11),
                        ),
                      ],
                    ],
                  )),
                  GoldButton(label: _paying ? 'Processing...' : 'Pay Now  ₹${plan.amount + due.lateFee}', onTap: _paying ? null : () => _pay(plan, due)),
                ],

                const SizedBox(height: 18),
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