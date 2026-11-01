import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/notification_service.dart';

/// Admin: sabhi customers ko app me message bhejo.
class AdminSendNotificationScreen extends StatefulWidget {
  const AdminSendNotificationScreen({super.key});

  @override
  State<AdminSendNotificationScreen> createState() => _AdminSendNotificationScreenState();
}

class _AdminSendNotificationScreenState extends State<AdminSendNotificationScreen> {
  final _svc = NotificationService();
  final _title = TextEditingController();
  final _body = TextEditingController();
  late final Stream<List<AppNotification>> _sent = _svc.watchLatest();
  bool _sending = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: AppText.bodyMuted,
    filled: true,
    fillColor: AppColors.charcoal,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: AppColors.gold.withOpacity(0.5)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: AppColors.gold.withOpacity(0.5)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.gold, width: 1.4),
    ),
  );

  Future<void> _send() async {
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.isEmpty || body.isEmpty) {
      _snack('Title aur message dono likho');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.charcoal,
        title: Text('Sabko bhejna hai?', style: AppText.heading.copyWith(fontSize: 17)),
        content: Text('Ye notification app ke sabhi customers ko dikhegi.',
            style: AppText.bodyMuted.copyWith(fontSize: 12.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Nahi')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Haan, bhejo', style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _sending = true);
    try {
      await _svc.send(title: title, body: body);
      _title.clear();
      _body.clear();
      _snack('Notification bhej di gayi');
    } catch (e) {
      _snack('Bhej nahi paye: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _fmt(DateTime d) =>
      '${d.day}/${d.month}/${d.year}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.gold),
        title: Text('Notification Bhejo', style: AppText.heading.copyWith(fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Title', style: AppText.body.copyWith(fontWeight: FontWeight.w600, fontSize: 13.5)),
            const SizedBox(height: 8),
            TextField(
              controller: _title,
              style: AppText.body,
              textCapitalization: TextCapitalization.sentences,
              decoration: _dec('Jaise: 🎉 Diwali Offer'),
            ),
            const SizedBox(height: 16),
            Text('Message', style: AppText.body.copyWith(fontWeight: FontWeight.w600, fontSize: 13.5)),
            const SizedBox(height: 8),
            TextField(
              controller: _body,
              style: AppText.body,
              minLines: 4,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              decoration: _dec('Customers ko kya batana hai...'),
            ),
            const SizedBox(height: 20),
            GoldButton(label: _sending ? 'Bhej rahe hain...' : 'App me sabko bhejo', onTap: _sending ? null : _send),
            const SizedBox(height: 8),
            Text(
              'Ye app ke andar bell (🔔) me dikhegi. Phone ke notification tray me tab nahi aayegi jab app band ho.',
              style: AppText.bodyMuted.copyWith(fontSize: 11, height: 1.4),
            ),
            const SizedBox(height: 26),
            Text('Pehle bheje hue', style: AppText.body.copyWith(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 12),
            StreamBuilder<List<AppNotification>>(
              stream: _sent,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Text('Load nahi hua: ${snap.error}', style: AppText.bodyMuted.copyWith(fontSize: 12));
                }
                final list = snap.data ?? const <AppNotification>[];
                if (list.isEmpty) {
                  return Text('Abhi tak kuch nahi bheja.', style: AppText.bodyMuted.copyWith(fontSize: 12.5));
                }
                return Column(
                  children: list
                      .map((n) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                    decoration: BoxDecoration(
                      color: AppColors.charcoal,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.gold.withOpacity(0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(n.title,
                                  style: AppText.body.copyWith(fontWeight: FontWeight.w700, fontSize: 13)),
                              const SizedBox(height: 3),
                              Text(n.body,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.bodyMuted.copyWith(fontSize: 11.5)),
                              const SizedBox(height: 4),
                              Text(_fmt(n.createdAt), style: AppText.bodyMuted.copyWith(fontSize: 10)),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Hatao',
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          onPressed: () => _svc.delete(n.id),
                        ),
                      ],
                    ),
                  ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}