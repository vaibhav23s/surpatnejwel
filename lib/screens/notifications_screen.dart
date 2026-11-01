import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

/// Home screen ki bell. Naya notification aaye to dot dikhata hai.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  final _svc = NotificationService();
  late final Stream<List<AppNotification>> _list = _svc.watchLatest();
  late final Stream<DateTime?> _seen = _svc.watchSeenAt();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppNotification>>(
      stream: _list,
      builder: (context, ns) {
        return StreamBuilder<DateTime?>(
          stream: _seen,
          builder: (context, ss) {
            final list = ns.data ?? const <AppNotification>[];
            final seen = ss.data;
            final unread = list.where((n) => seen == null || n.createdAt.isAfter(seen)).length;
            return GoldCircleIcon(
              icon: Icons.notifications_none,
              hasDot: unread > 0,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              ),
            );
          },
        );
      },
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _svc = NotificationService();
  final _auth = AuthService();
  late final Stream<List<AppNotification>> _stream = _svc.watchLatest();
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _svc.markAllSeen().catchError((_) {});
    _auth.isAdmin().then((v) {
      if (mounted) setState(() => _isAdmin = v);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _svc.markAllSeen().catchError((_) {});
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.day}/${d.month}/${d.year}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Future<void> _delete(AppNotification n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cream,
        title: const Text('Hatana hai?', style: TextStyle(color: AppColors.charcoal, fontWeight: FontWeight.w800)),
        content: const Text('Ye notification sabke liye hat jayegi.', style: TextStyle(color: Colors.black54)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Nahi')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Haan, hatao', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.delete(n.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hat nahi paya: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.goldDark),
        title: Text('Notifications', style: AppText.heading.copyWith(color: AppColors.black, fontSize: 20)),
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Load nahi ho paya.\n\n${snap.error}',
                    textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, fontSize: 12)),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.gold));
          }
          final list = snap.data!;
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_off_outlined, color: AppColors.gold.withOpacity(0.6), size: 44),
                  const SizedBox(height: 10),
                  const Text('Abhi koi notification nahi hai.', style: TextStyle(color: Colors.black54)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 30),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final n = list[i];
              final isRate = n.type == 'rate';
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.goldGradient,
                      ),
                      child: Icon(
                        isRate ? Icons.currency_rupee : Icons.campaign_outlined,
                        color: AppColors.black,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(n.title,
                              style: const TextStyle(
                                  color: AppColors.charcoal, fontSize: 14, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 5),
                          Text(n.body,
                              style: TextStyle(
                                  color: AppColors.charcoal.withOpacity(0.78), fontSize: 12.5, height: 1.45)),
                          const SizedBox(height: 8),
                          Text(_fmt(n.createdAt),
                              style: TextStyle(color: AppColors.charcoal.withOpacity(0.45), fontSize: 10.5)),
                        ],
                      ),
                    ),
                    if (_isAdmin)
                      IconButton(
                        tooltip: 'Hatao',
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                        onPressed: () => _delete(n),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}