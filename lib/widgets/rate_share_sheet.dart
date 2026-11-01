import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/rate_store.dart';
import '../services/notification_service.dart';
import '../utils/currency_format.dart';

/// Aaj ke bhav ka WhatsApp wala sundar text.
/// Gold value = 1 gram ka rate, Silver value = 10 gram ka rate.
String buildRateMessage(DailyRates r, {DateTime? now}) {
  final d = now ?? DateTime.now();

  String change(double cur, double? prev) {
    if (prev == null || prev == 0 || cur == prev) return '';
    final diff = cur - prev;
    return diff > 0 ? '  🔺 +₹${formatInr(diff.abs())}' : '  🔻 -₹${formatInr(diff.abs())}';
  }

  return '✨ *सूरपाटणे ज्वेलर्स* ✨\n'
      '📅 Aaj ka bhav — ${d.day}/${d.month}/${d.year}\n\n'
      '🥇 *Gold 24K* (1 gram): ₹${formatInr(r.gold10gInr)}${change(r.gold10gInr, r.previousGold10gInr)}\n'
      '🥈 *Silver* (10 gram): ₹${formatInr(r.silverKgInr)}${change(r.silverKgInr, r.previousSilverKgInr)}\n\n'
      '💎 Shuddh sona-chandi, bharose ka naam.\n'
      '🙏 Kharidari ya jaankari ke liye shop par padharein.\n'
      '📞 9356446941  |  9403463733\n\n'
      '📲 Roz ka bhav hamare app me bhi dekhein.';
}

Future<void> showRateShareSheet(BuildContext context, DailyRates rates) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RateShareSheet(rates: rates),
  );
}

/// Abhi ka rate leke sheet kholta hai (drawer se use hota hai).
Future<void> openRateShare(BuildContext context) async {
  try {
    final r = await RateStore().watchRates().first.timeout(const Duration(seconds: 8));
    if (!context.mounted) return;
    await showRateShareSheet(context, r);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rate load nahi hua: $e')));
    }
  }
}

class _RateShareSheet extends StatefulWidget {
  final DailyRates rates;
  const _RateShareSheet({required this.rates});

  @override
  State<_RateShareSheet> createState() => _RateShareSheetState();
}

class _RateShareSheetState extends State<_RateShareSheet> {
  late final TextEditingController _c = TextEditingController(text: buildRateMessage(widget.rates));
  bool _sendingApp = false;
  bool _sentApp = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _whatsapp() async {
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(_c.text)}');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) _snack('WhatsApp open nahi ho paya');
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _c.text));
    _snack('Text copy ho gaya');
  }

  Future<void> _sendApp() async {
    setState(() => _sendingApp = true);
    try {
      await NotificationService().send(
        title: '📢 Aaj ka bhav',
        body: _c.text.replaceAll('*', ''),
        type: 'rate',
      );
      if (mounted) setState(() => _sentApp = true);
    } catch (e) {
      _snack('Bhej nahi paye: $e');
    } finally {
      if (mounted) setState(() => _sendingApp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        decoration: const BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Aaj ka bhav bhejo',
                          style: TextStyle(color: AppColors.charcoal, fontSize: 19, fontWeight: FontWeight.w800)),
                    ),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                  ],
                ),
                Text('Neeche ka text chaho to badal sakte ho.',
                    style: TextStyle(color: AppColors.charcoal.withOpacity(0.6), fontSize: 12)),
                const SizedBox(height: 12),
                TextField(
                  controller: _c,
                  minLines: 8,
                  maxLines: 12,
                  style: const TextStyle(color: AppColors.charcoal, fontSize: 13, height: 1.45),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppColors.gold.withOpacity(0.4)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppColors.gold.withOpacity(0.4)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _whatsapp,
                    icon: const Icon(Icons.chat_rounded),
                    label: const Text('WhatsApp group me bhejo',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                  ),
                ),
                const SizedBox(height: 4),
                Text('WhatsApp khulega: group chuno aur Send dabao.',
                    style: TextStyle(color: AppColors.charcoal.withOpacity(0.5), fontSize: 10.5)),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.gold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: (_sendingApp || _sentApp) ? null : _sendApp,
                    icon: Icon(_sentApp ? Icons.check_circle : Icons.notifications_active_outlined,
                        color: AppColors.goldDark),
                    label: Text(
                      _sentApp
                          ? 'App me bhej diya ✓'
                          : (_sendingApp ? 'Bhej rahe hain...' : 'App me sabko notification bhejo'),
                      style: const TextStyle(color: AppColors.goldDark, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: TextButton.icon(
                    onPressed: _copy,
                    icon: const Icon(Icons.copy, size: 16, color: Colors.black54),
                    label: const Text('Text copy karo', style: TextStyle(color: Colors.black54)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}