import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:surpatne_jewellers/screens/sip_payment_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/state_views.dart';
import '../services/rate_store.dart';
import '../services/investment_service.dart';
import '../services/investment_lock_service.dart';
import '../services/user_service.dart';
import '../services/sip_service.dart';
import '../utils/app_errors.dart';
import '../utils/currency_format.dart';

// Legal PAN-quoting threshold for gold/bullion purchases in India.
// A single transaction at or above this amount requires PAN, per
// PMLA rules. Below this, PAN is not legally required, so the field
// stays hidden to keep the flow fast.
const double kPanRequiredAboveInr = 200000;

final RegExp _kPanFormat = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$');

String _maskPan(String pan) {
  if (pan.length < 10) return pan;
  return '${pan.substring(0, 5)}****${pan.substring(9)}';
}

// Shop's WhatsApp + Call number for the floating contact button below.
const String kInvestSupportPhone10Digit = '9356446941';
const String kInvestSupportPhoneIntl = '+919356446941';

// ============================================================
// Razorpay Key ID. Only the Key ID goes in the app, NEVER the Key Secret.
// Test key starts with rzp_test_ and live key starts with rzp_live_.
// ============================================================
const String kRazorpayKeyId = 'rzp_test_T6mmzxRi06sWfX';

bool get _isTestKey => kRazorpayKeyId.startsWith('rzp_test_');

class InvestmentScreen extends StatefulWidget {
  const InvestmentScreen({super.key});

  @override
  State<InvestmentScreen> createState() => _InvestmentScreenState();
}

class _InvestmentScreenState extends State<InvestmentScreen> {
  final InvestmentLockService _lockService = InvestmentLockService();

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _launchWhatsApp() async {
    final message = Uri.encodeComponent(
      'Hello Surpatne Jewellers!\n\n'
          'I would like to know more about Gold & Silver Investment.\n\n'
          'Please share the investment options, current rates, the minimum '
          'investment amount and how the process works.\n\n'
          'Thank you!\n'
          '- Surpatne Jewellers Customer',
    );

    final uri = Uri.parse(
      'https://wa.me/91$kInvestSupportPhone10Digit?text=$message',
    );

    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) _snack('Could not open WhatsApp.');
    } catch (_) {
      _snack('Could not open WhatsApp.');
    }
  }

  Future<void> _launchCall() async {
    final uri = Uri(scheme: 'tel', path: kInvestSupportPhoneIntl);
    try {
      final ok = await launchUrl(uri);
      if (!ok) _snack('Could not start the call.');
    } catch (_) {
      _snack('Could not start the call.');
    }
  }

  void _showContactSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ask about investment',
                  style: AppText.heading.copyWith(color: AppColors.black, fontSize: 17),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: Color(0xFF25D366),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 20),
                  ),
                  title: Text(
                    'Message us on WhatsApp',
                    style: AppText.body.copyWith(
                      color: AppColors.black,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _launchWhatsApp();
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      gradient: AppColors.goldGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.call_outlined, color: AppColors.black, size: 20),
                  ),
                  title: Text(
                    'Call the shop',
                    style: AppText.body.copyWith(
                      color: AppColors.black,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _launchCall();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.goldDark),
        title: Text(
          'Investment',
          style: AppText.heading.copyWith(color: AppColors.black, fontSize: 20),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF25D366),
        onPressed: _showContactSheet,
        child: const Icon(Icons.chat_bubble, color: Colors.white),
      ),
      body: SafeStream<InvestmentLocks>(
        create: () => _lockService.watchLocks(),
        builder: (context, locks) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ------------------------------------------------
                // SECTION 1: SIP planner
                // ------------------------------------------------
                const _SectionTitle('GOLD & SILVER SIP'),
                const SizedBox(height: 16),
                Stack(
                  children: [
                    IgnorePointer(
                      ignoring: locks.sipLocked,
                      child: ImageFiltered(
                        enabled: locks.sipLocked,
                        imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                        child: _SipPreview(
                          onStart: locks.sipLocked
                              ? null
                              : () => openSipWithCode(context, kRazorpayKeyId),
                        ),
                      ),
                    ),
                    if (locks.sipLocked)
                      const _ComingSoonOverlay(
                        title: 'SIP Coming Soon',
                        subtitle: 'Gold & Silver SIP will start soon.\nPlease wait a little!',
                      ),
                  ],
                ),

                const SizedBox(height: 34),

                // ------------------------------------------------
                // SECTION 2: Quick Buy
                // ------------------------------------------------
                const _SectionTitle('QUICK BUY'),
                const SizedBox(height: 16),
                Stack(
                  children: [
                    IgnorePointer(
                      ignoring: locks.quickBuyLocked,
                      child: ImageFiltered(
                        enabled: locks.quickBuyLocked,
                        imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                        child: const _QuickBuySection(),
                      ),
                    ),
                    if (locks.quickBuyLocked)
                      const _ComingSoonOverlay(
                        title: 'Quick Buy Coming Soon',
                        subtitle: 'Buying live gold and silver will start soon.\nPlease wait a little!',
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// Shared bits
// ============================================================

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: AppColors.gold.withOpacity(0.4))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            title,
            style: AppText.goldLabel.copyWith(fontSize: 13, letterSpacing: 1.5),
          ),
        ),
        Expanded(child: Container(height: 1, color: AppColors.gold.withOpacity(0.4))),
      ],
    );
  }
}

class _ComingSoonOverlay extends StatelessWidget {
  final String title;
  final String subtitle;
  const _ComingSoonOverlay({
    this.title = 'Coming Soon',
    this.subtitle = 'This feature will start soon.\nPlease wait a little!',
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.white.withOpacity(0.55),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.gold.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.goldGradient,
                ),
                child: const Icon(Icons.lock_outline, color: AppColors.black, size: 26),
              ),
              const SizedBox(height: 16),
              Text(title, style: AppText.heading.copyWith(color: AppColors.black, fontSize: 20)),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: AppText.bodyMuted.copyWith(
                  color: Colors.black54,
                  fontSize: 12.5,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// SECTION 1: SIP (runs on a shop code)
// ============================================================

class _SipPreview extends StatefulWidget {
  final VoidCallback? onStart;
  const _SipPreview({this.onStart});

  @override
  State<_SipPreview> createState() => _SipPreviewState();
}

class _SipPreviewState extends State<_SipPreview> {
  final RateStore _rateStore = RateStore();
  StreamSubscription<DailyRates>? _ratesSub;
  DailyRates? _rates;

  bool _gold = true;
  int _index = 1; // slider position -> which amount

  List<int> get _amounts => _gold ? kGoldSipAmounts : kSilverSipAmounts;
  int get _amount => _amounts[_index.clamp(0, _amounts.length - 1)];

  /// Live per-gram rate (same RateStore the home screen uses).
  /// Gold value = rate of 1 gram. Silver value = rate of 10 grams.
  double? get _ratePerGram {
    if (_rates == null) return null;
    final r = _gold ? _rates!.gold10gInr : _rates!.silverKgInr / 10;
    return r > 0 ? r : null;
  }

  @override
  void initState() {
    super.initState();
    _ratesSub = _rateStore.watchRates().listen(
          (r) {
        if (mounted) setState(() => _rates = r);
      },
      onError: (e) => AppErrors.log(e),
    );
  }

  @override
  void dispose() {
    _ratesSub?.cancel();
    super.dispose();
  }

  /// Switching metal keeps the closest amount that exists for the new
  /// metal (gold and silver have different amount lists).
  void _setMetal(bool gold) {
    if (gold == _gold) return;
    final old = _amount;
    setState(() {
      _gold = gold;
      final list = _amounts;
      var best = 0;
      for (var i = 0; i < list.length; i++) {
        if ((list[i] - old).abs() < (list[best] - old).abs()) best = i;
      }
      _index = best;
    });
  }

  Widget _kv(String l, String r, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              l,
              style: AppText.bodyMuted.copyWith(color: Colors.black54, fontSize: 12.5),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            r,
            style: AppText.body.copyWith(
              color: bold ? AppColors.goldDark : AppColors.black,
              fontSize: bold ? 15 : 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amount = _amount;
    final totalInvest = amount * kSipMonths;
    final rate = _ratePerGram;
    final metalName = _gold ? 'Gold' : 'Silver';
    final digits = _gold ? 4 : 3;

    final now = DateTime.now();
    final firstInstallment = DateTime(now.year, now.month + 1, 1);
    final lastInstallment =
    DateTime(firstInstallment.year, firstInstallment.month + kSipMonths - 1, 1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Save a little every month for your big dreams',
            style: AppText.bodyMuted.copyWith(color: Colors.black54, fontSize: 13),
          ),
          const SizedBox(height: 18),

          // --- metal ---
          Row(
            children: [
              Expanded(
                child: _SipMetalTile(
                  label: 'Gold SIP',
                  sub: '24K • 99.9%',
                  selected: _gold,
                  gold: true,
                  onTap: () => _setMetal(true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SipMetalTile(
                  label: 'Silver SIP',
                  sub: '99.9% Pure',
                  selected: !_gold,
                  gold: false,
                  onTap: () => _setMetal(false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // --- amount: big number + slider + chips ---
          Text(
            'Monthly SIP amount',
            style: AppText.body.copyWith(
              color: AppColors.black,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.gold.withOpacity(0.4)),
            ),
            child: Column(
              children: [
                Text(
                  '₹ ${formatInr(amount)}',
                  style: AppText.heading.copyWith(fontSize: 30, color: AppColors.goldDark),
                ),
                Text(
                  'per month',
                  style: AppText.bodyMuted.copyWith(color: Colors.black54, fontSize: 11),
                ),
              ],
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.gold,
              inactiveTrackColor: AppColors.gold.withOpacity(0.2),
              thumbColor: AppColors.goldDark,
              overlayColor: AppColors.gold.withOpacity(0.15),
              activeTickMarkColor: Colors.white,
              inactiveTickMarkColor: AppColors.gold.withOpacity(0.5),
              trackHeight: 5,
            ),
            child: Slider(
              value: _index.toDouble(),
              min: 0,
              max: (_amounts.length - 1).toDouble(),
              divisions: _amounts.length - 1,
              label: '₹${formatInr(amount)}',
              onChanged: (v) => setState(() => _index = v.round()),
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(_amounts.length, (i) {
              return _SipAmountChip(
                label: '₹${formatInr(_amounts[i])}',
                active: i == _index,
                onTap: () => setState(() => _index = i),
              );
            }),
          ),
          const SizedBox(height: 22),

          // --- fixed plan facts ---
          Row(
            children: [
              Expanded(child: _SipStat(label: 'Duration', value: '$kSipMonths months')),
              const SizedBox(width: 8),
              const Expanded(child: _SipStat(label: 'Due date', value: '1st of every month')),
              const SizedBox(width: 8),
              Expanded(
                child: _SipStat(
                  label: 'First instalment',
                  value: sipMonthLabel(firstInstallment),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // --- overview ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.gold.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PLAN OVERVIEW',
                  style: AppText.goldLabel.copyWith(fontSize: 11, letterSpacing: 1.2),
                ),
                const SizedBox(height: 8),
                _kv('Monthly instalment', '₹${formatInr(amount)}'),
                _kv(
                  'Total instalments',
                  '$kSipMonths  (${sipMonthLabel(firstInstallment)} - ${sipMonthLabel(lastInstallment)})',
                ),
                const Divider(height: 18),
                _kv(
                  'Total investment ($kSipMonths months)',
                  '₹${formatInr(totalInvest)}',
                  bold: true,
                ),
                _kv(
                  "Approx. $metalName collected at today's rate",
                  rate == null
                      ? 'Rate is loading…'
                      : '${(totalInvest / rate).toStringAsFixed(digits)} g',
                  bold: true,
                ),
                _kv(
                  'Approx. per instalment',
                  rate == null ? '—' : '${(amount / rate).toStringAsFixed(digits)} g',
                ),
                _kv(
                  "Today's $metalName rate",
                  rate == null ? '—' : '₹${rate.toStringAsFixed(2)} / gram',
                ),
                const SizedBox(height: 14),
                Text(
                  'Total amount paid (after each instalment)',
                  style: AppText.bodyMuted.copyWith(color: Colors.black54, fontSize: 11),
                ),
                const SizedBox(height: 8),
                _SipBars(months: kSipMonths),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'No. 1: ₹${formatInr(amount)}',
                      style: AppText.bodyMuted.copyWith(color: Colors.black54, fontSize: 10.5),
                    ),
                    Text(
                      'No. ${kSipMonths ~/ 2}: ₹${formatInr(amount * (kSipMonths ~/ 2))}',
                      style: AppText.bodyMuted.copyWith(color: Colors.black54, fontSize: 10.5),
                    ),
                    Text(
                      'No. $kSipMonths: ₹${formatInr(totalInvest)}',
                      style: AppText.body.copyWith(
                        color: AppColors.goldDark,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'This is only an estimate. The actual $metalName is credited at the rate on the day of each '
                      'instalment, so the final quantity may go up or down. Profit is not guaranteed.',
                  style: AppText.bodyMuted.copyWith(
                    color: Colors.black54,
                    fontSize: 10.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // --- key terms in short ---
          Text(
            '• 1st to ${_ordinal(kSipLastFreeDay)} of the month: no late fee. From the next day, a late fee of '
                '₹$kSipLateFeeStep applies and it increases by ₹$kSipLateFeeStep for every following month '
                '(no $metalName is credited for late fees).\n'
                '• After $kSipMonths months you can collect your item at that day\'s rate, with 50% off on making charges.',
            style: AppText.bodyMuted.copyWith(color: Colors.black54, fontSize: 11, height: 1.5),
          ),
          const SizedBox(height: 18),

          GoldButton(label: 'Get Started', onTap: widget.onStart),
          const SizedBox(height: 8),
          Text(
            'To start a SIP, first fill in the form at the shop (choose the same metal and amount you see here). '
                'The shop will give you a 6 digit SIP code. Once you have the code, tap "Get Started".',
            style: AppText.bodyMuted.copyWith(color: Colors.black45, fontSize: 10.5, height: 1.4),
          ),
        ],
      ),
    );
  }

  static String _ordinal(int n) {
    if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }
}

class _SipMetalTile extends StatelessWidget {
  final String label;
  final String sub;
  final bool selected;
  final bool gold;
  final VoidCallback onTap;
  const _SipMetalTile({
    required this.label,
    required this.sub,
    required this.selected,
    required this.gold,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.gold : AppColors.gold.withOpacity(0.25),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: gold
                    ? AppColors.goldGradient
                    : const LinearGradient(colors: [Color(0xFFB8B8B8), Color(0xFFE8E8E8)]),
              ),
              child: Icon(Icons.diamond, size: 18, color: AppColors.black.withOpacity(0.55)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppText.body.copyWith(
                      color: AppColors.black,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    sub,
                    style: AppText.bodyMuted.copyWith(color: Colors.black54, fontSize: 10.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SipAmountChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _SipAmountChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          gradient: active ? AppColors.goldGradient : null,
          color: active ? null : AppColors.cream,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? Colors.transparent : AppColors.gold.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? AppColors.black : Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }
}

class _SipStat extends StatelessWidget {
  final String label;
  final String value;
  const _SipStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppText.bodyMuted.copyWith(color: Colors.black54, fontSize: 10),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: AppText.body.copyWith(
              color: AppColors.black,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small bar chart: one bar per instalment, growing as the total paid-in grows.
class _SipBars extends StatelessWidget {
  final int months;
  const _SipBars({required this.months});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(months, (i) {
        final last = i == months - 1;
        final h = 10 + 54 * (i + 1) / months;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Container(
              height: h,
              decoration: BoxDecoration(
                gradient: last ? AppColors.goldGradient : null,
                color: last ? null : AppColors.gold.withOpacity(0.25 + 0.45 * i / months),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ============================================================
// SECTION 2: Quick Buy (live Razorpay purchase)
// ============================================================

class _QuickBuySection extends StatefulWidget {
  const _QuickBuySection();

  @override
  State<_QuickBuySection> createState() => _QuickBuySectionState();
}

class _QuickBuySectionState extends State<_QuickBuySection> {
  final RateStore _rateStore = RateStore();
  final InvestmentService _investmentService = InvestmentService();
  final UserService _userService = UserService();
  final Razorpay _razorpay = Razorpay();
  StreamSubscription<DailyRates>? _ratesSub;

  final TextEditingController _gramsController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _panController = TextEditingController();
  bool _editingGrams = false;

  bool _goldSelected = true;
  bool _paying = false;
  DailyRates? _rates;

  double? _pendingAmount, _pendingGrams, _pendingRatePerGram;
  String? _pendingMetal;
  String? _pendingPan;

  @override
  void initState() {
    super.initState();
    _ratesSub = _rateStore.watchRates().listen(
          (r) {
        if (!mounted) return;
        setState(() => _rates = r);
        _recalculate();
      },
      onError: (e) => AppErrors.log(e),
    );
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
    _amountController.text = '500';
    _recalculate();
    _userService.getProfile().then((p) {
      if (mounted && p != null && p.pan.isNotEmpty) {
        setState(() => _panController.text = p.pan);
      }
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _ratesSub?.cancel();
    _razorpay.clear();
    _gramsController.dispose();
    _amountController.dispose();
    _panController.dispose();
    super.dispose();
  }

  /// Gold value = rate of 1 gram. Silver value = rate of 10 grams.
  double? get _pricePerGram {
    if (_rates == null) return null;
    return _goldSelected ? _rates!.gold10gInr : _rates!.silverKgInr / 10;
  }

  void _recalculate() {
    final price = _pricePerGram;
    if (price == null || price <= 0) return;
    if (_editingGrams) {
      final grams = double.tryParse(_gramsController.text.trim()) ?? 0;
      _amountController.text = (grams * price).toStringAsFixed(2);
    } else {
      final amount = double.tryParse(_amountController.text.trim()) ?? 0;
      _gramsController.text = (amount / price).toStringAsFixed(4);
    }
    if (mounted) setState(() {});
  }

  void _onMetalChanged(bool gold) {
    setState(() => _goldSelected = gold);
    _recalculate();
  }

  void _clearPending() {
    _pendingAmount = _pendingGrams = _pendingRatePerGram = null;
    _pendingMetal = null;
    _pendingPan = null;
  }

  Future<void> _buyNow() async {
    if (_paying) return;

    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final grams = double.tryParse(_gramsController.text.trim()) ?? 0;
    final price = _pricePerGram;

    if (amount < 1) {
      _snack('Please enter an amount of at least ₹1.');
      return;
    }
    if (price == null || grams <= 0) {
      _snack('The live rate is still loading. Please wait a moment and try again.');
      return;
    }
    if (kRazorpayKeyId.contains('REPLACE_ME')) {
      _snack('Payments are not available right now. Please contact the shop.');
      return;
    }

    // Legal requirement: PAN must be quoted for a single transaction
    // of ₹2 lakh or more.
    String? pan;
    if (amount >= kPanRequiredAboveInr) {
      pan = _panController.text.trim().toUpperCase();
      if (pan.isEmpty) {
        _snack(
          'PAN number is required for purchases of ₹${kPanRequiredAboveInr.toStringAsFixed(0)} or more.',
        );
        return;
      }
      if (!_kPanFormat.hasMatch(pan)) {
        _snack('PAN format is not valid (example: ABCDE1234F).');
        return;
      }
    }

    setState(() => _paying = true);

    if (!await Net.isOnline()) {
      if (mounted) setState(() => _paying = false);
      _snack(AppErrors.noInternet);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    _pendingAmount = amount;
    _pendingGrams = grams;
    _pendingRatePerGram = price;
    _pendingMetal = _goldSelected ? 'gold' : 'silver';
    _pendingPan = pan;

    final options = {
      'key': kRazorpayKeyId,
      'amount': (amount * 100).round(),
      'name': 'Surpatne Jewellers',
      'description': '${grams.toStringAsFixed(4)}g ${_pendingMetal!.toUpperCase()} purchase',
      'prefill': {'contact': '', 'email': user?.email ?? ''},
      'theme': {'color': '#D4AF37'},
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      _clearPending();
      if (mounted) setState(() => _paying = false);
      _snack(AppErrors.message(e));
    }
  }

  Future<void> _saveQuickBuy(String paymentId) async {
    final metal = _pendingMetal;
    final amount = _pendingAmount;
    final grams = _pendingGrams;
    final rate = _pendingRatePerGram;
    final pan = _pendingPan;
    if (metal == null || amount == null || grams == null || rate == null) return;

    final hasPan = pan != null && pan.isNotEmpty;

    await _investmentService.recordPurchase(
      metal: metal,
      amountInr: amount,
      grams: grams,
      ratePerGramInr: rate,
      razorpayPaymentId: paymentId,
      panMasked: hasPan ? _maskPan(pan) : null,
    );

    // Saving PAN to the profile is a convenience, so a failure here is ignored.
    if (hasPan) {
      try {
        await _userService.updateProfile(pan: pan);
      } catch (_) {}
    }
  }

  Future<void> _onPaymentSuccess(PaymentSuccessResponse response) async {
    final paymentId = response.paymentId ?? '';
    final amount = _pendingAmount?.round();
    final grams = _pendingGrams;
    final metal = _pendingMetal;

    try {
      await Net.withTimeout(_saveQuickBuy(paymentId), const Duration(seconds: 25));
      _snack(
        'Payment successful. ${grams?.toStringAsFixed(4)} g $metal has been added to your account.',
      );
    } catch (e) {
      AppErrors.log(e);
      if (mounted) {
        await showPaidNotSavedDialog(
          context,
          paymentId: paymentId,
          amount: amount,
          mayAutoUpdate: e is TimeoutException,
        );
      }
    } finally {
      if (mounted) setState(() => _paying = false);
      _clearPending();
    }
  }

  void _onPaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    setState(() => _paying = false);
    _clearPending();
    _snack(AppErrors.razorpay(response));
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;
    setState(() => _paying = false);
    _snack('Wallet selected: ${response.walletName}');
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  InputDecoration _fieldDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: AppColors.cream,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.gold.withOpacity(0.4)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.gold.withOpacity(0.4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.gold, width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (kRazorpayKeyId.contains('REPLACE_ME'))
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
            ),
            child: Text(
              'Razorpay key is not set. Add your rzp_test_... key in kRazorpayKeyId.',
              style: AppText.bodyMuted.copyWith(fontSize: 11.5, color: Colors.red.shade700),
            ),
          ),

        // --- Balance in grams ---
        StreamBuilder<InvestmentHolding>(
          stream: _investmentService.watchHoldings(),
          builder: (context, snapshot) {
            final h =
                snapshot.data ?? const InvestmentHolding(goldGrams: 0, silverGrams: 0);
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BALANCE IN GRAMS',
                    style: AppText.goldLabel.copyWith(fontSize: 11, letterSpacing: 1),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _BalanceTile(
                          label: 'Gold (24K-995)',
                          grams: h.goldGrams,
                          rate: _rates == null ? null : _rates!.gold10gInr,
                          gold: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _BalanceTile(
                          label: 'Silver (24K-999)',
                          grams: h.silverGrams,
                          rate: _rates == null ? null : _rates!.silverKgInr / 10,
                          gold: false,
                        ),
                      ),
                    ],
                  ),
                  if (snapshot.hasError) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Could not load your balance. ${AppErrors.message(snapshot.error!)}',
                      style: TextStyle(color: Colors.red.shade600, fontSize: 11),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: _MetalToggle(
                label: 'Gold',
                selected: _goldSelected,
                gold: true,
                onTap: () => _onMetalChanged(true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetalToggle(
                label: 'Silver',
                selected: !_goldSelected,
                gold: false,
                onTap: () => _onMetalChanged(false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Grams',
                    style: AppText.bodyMuted.copyWith(color: Colors.black54, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _gramsController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: AppText.body.copyWith(
                      color: AppColors.black,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () => _editingGrams = true,
                    onChanged: (_) => _recalculate(),
                    decoration: _fieldDecoration(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 30, left: 8, right: 8),
              child: Icon(Icons.swap_horiz, color: AppColors.gold.withOpacity(0.8)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Amount (₹)',
                    style: AppText.bodyMuted.copyWith(color: Colors.black54, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: AppText.body.copyWith(
                      color: AppColors.black,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () => _editingGrams = false,
                    onChanged: (_) => _recalculate(),
                    decoration: _fieldDecoration(),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _pricePerGram == null
              ? 'Rate is loading…'
              : 'Current rate: ₹${_pricePerGram!.toStringAsFixed(2)}/gm (${_goldSelected ? "Gold" : "Silver"})',
          style: AppText.bodyMuted.copyWith(color: Colors.black54, fontSize: 11.5),
        ),

        // PAN is a legal requirement only at ₹2 lakh+ per transaction,
        // so the field only appears once the amount crosses that.
        if ((double.tryParse(_amountController.text.trim()) ?? 0) >= kPanRequiredAboveInr) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.gold.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: AppColors.goldDark, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'A PAN number is required for purchases of ₹${kPanRequiredAboveInr.toStringAsFixed(0)} or more (as per government rules).',
                    style: AppText.bodyMuted.copyWith(color: Colors.black87, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _panController,
            textCapitalization: TextCapitalization.characters,
            maxLength: 10,
            style: AppText.body.copyWith(
              color: AppColors.black,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
            decoration: _fieldDecoration().copyWith(
              hintText: 'PAN Number (e.g. ABCDE1234F)',
              counterText: '',
              prefixIcon: Icon(Icons.badge_outlined, color: AppColors.goldDark),
            ),
          ),
        ],
        const SizedBox(height: 20),

        GoldButton(
          label: _paying ? 'Processing...' : 'Buy Now',
          onTap: _paying ? null : _buyNow,
        ),
        if (_isTestKey) ...[
          const SizedBox(height: 8),
          Text(
            'TEST MODE: no real money will be charged.',
            textAlign: TextAlign.center,
            style: AppText.bodyMuted.copyWith(color: Colors.black45, fontSize: 10.5),
          ),
        ],
        const SizedBox(height: 26),

        Text(
          'Purchase History',
          style: AppText.body.copyWith(
            color: AppColors.black,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<InvestmentTransaction>>(
          stream: _investmentService.watchTransactions(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'Could not load your purchase history. ${AppErrors.message(snapshot.error!)}',
                  style: TextStyle(color: Colors.red.shade600, fontSize: 12),
                ),
              );
            }
            final txns = snapshot.data ?? [];
            if (txns.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'No purchases yet.',
                  style: AppText.bodyMuted.copyWith(color: Colors.black54, fontSize: 12.5),
                ),
              );
            }
            return Column(children: txns.map((t) => _TxnRow(txn: t)).toList());
          },
        ),
      ],
    );
  }
}

class _BalanceTile extends StatelessWidget {
  final String label;
  final double grams;
  final double? rate;
  final bool gold;
  const _BalanceTile({
    required this.label,
    required this.grams,
    required this.rate,
    required this.gold,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: gold
                      ? AppColors.goldGradient
                      : const LinearGradient(colors: [Color(0xFFB8B8B8), Color(0xFFE8E8E8)]),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: AppText.bodyMuted.copyWith(color: Colors.black54, fontSize: 10.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${grams.toStringAsFixed(4)} g',
            style: AppText.body.copyWith(
              color: AppColors.black,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            rate == null ? '—' : '₹${rate!.toStringAsFixed(0)}/gm',
            style: AppText.goldLabel.copyWith(fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

class _MetalToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final bool gold;
  final VoidCallback onTap;
  const _MetalToggle({
    required this.label,
    required this.selected,
    required this.gold,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.goldGradient : null,
          color: selected ? null : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Colors.transparent : AppColors.gold.withOpacity(0.3),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.black : Colors.black87,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _TxnRow extends StatelessWidget {
  final InvestmentTransaction txn;
  const _TxnRow({required this.txn});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(
            txn.metal == 'gold' ? Icons.circle : Icons.circle_outlined,
            color: AppColors.gold,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${txn.grams.toStringAsFixed(4)} g ${txn.metal}',
                  style: AppText.body.copyWith(
                    color: AppColors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${txn.purchasedAt.day}/${txn.purchasedAt.month}/${txn.purchasedAt.year} • ₹${txn.ratePerGramInr.toStringAsFixed(2)}/g',
                  style: AppText.bodyMuted.copyWith(color: Colors.black54, fontSize: 10.5),
                ),
              ],
            ),
          ),
          Text(
            '₹${formatInr(txn.amountInr)}',
            style: AppText.body.copyWith(
              color: AppColors.black,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}