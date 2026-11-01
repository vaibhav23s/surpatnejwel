import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/investment_lock_service.dart';

/// Admin-only screen: turn the Investment screen's two sections
/// (SIP, Quick Buy) on or off for every customer. Only reachable from
/// the drawer when the signed-in user is an admin (see rashifal_drawer.dart).
class ManageInvestmentScreen extends StatelessWidget {
  const ManageInvestmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lockService = InvestmentLockService();

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.gold),
        title: Text('Investment Manage Karo', style: AppText.heading.copyWith(fontSize: 18)),
      ),
      body: StreamBuilder<InvestmentLocks>(
        stream: lockService.watchLocks(),
        builder: (context, snapshot) {
          final locks = snapshot.data ?? const InvestmentLocks(sipLocked: true, quickBuyLocked: true);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customer ko ye sections dikhne chahiye ya "Coming Soon" lock ke peeche rehne chahiye — yahan se decide karo.',
                  style: AppText.bodyMuted.copyWith(fontSize: 12.5),
                ),
                const SizedBox(height: 22),
                _LockTile(
                  title: 'Gold & Silver SIP',
                  subtitle: locks.sipLocked ? 'Locked hai — customer ko "Coming Soon" dikhega' : 'Live hai — customer use kar sakta hai',
                  locked: locks.sipLocked,
                  onChanged: (unlocked) => lockService.setSipLocked(!unlocked),
                ),
                const SizedBox(height: 14),
                _LockTile(
                  title: 'Quick Buy (live purchase)',
                  subtitle: locks.quickBuyLocked ? 'Locked hai — customer ko "Coming Soon" dikhega' : 'Live hai — customer khareed sakta hai',
                  locked: locks.quickBuyLocked,
                  onChanged: (unlocked) => lockService.setQuickBuyLocked(!unlocked),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LockTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool locked;
  final ValueChanged<bool> onChanged; // called with "unlocked" value

  const _LockTile({
    required this.title,
    required this.subtitle,
    required this.locked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.charcoal,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(locked ? Icons.lock_outline : Icons.lock_open_outlined, color: AppColors.gold, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.body.copyWith(fontWeight: FontWeight.w600, fontSize: 14.5)),
                const SizedBox(height: 3),
                Text(subtitle, style: AppText.bodyMuted.copyWith(fontSize: 11.5)),
              ],
            ),
          ),
          Switch(
            value: !locked, // switch ON means unlocked/live
            activeColor: AppColors.gold,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}