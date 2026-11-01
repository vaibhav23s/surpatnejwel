import 'package:flutter/material.dart';
import '../screens/manage_big_ad_screen.dart';
import '../screens/rashe_screen.dart';
import '../screens/manage_ads_screen.dart';
import '../screens/manage_investment_screen.dart';
import '../screens/admin_investment_report_screen.dart';
import '../screens/admin_girvi_list_screen.dart';
import '../screens/admin_sip_form_screen.dart';
import '../screens/admin_sip_report_screen.dart';
import '../screens/admin_send_notification_screen.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'common_widgets.dart';
import 'rate_share_sheet.dart';

/// App side drawer. Customers ko sirf Rashifal dikhta hai.
/// Admin-only items tabhi dikhte hain jab admin login ho.
class RashifalDrawer extends StatefulWidget {
  const RashifalDrawer({super.key});

  @override
  State<RashifalDrawer> createState() => _RashifalDrawerState();
}

class _RashifalDrawerState extends State<RashifalDrawer> {
  final _authService = AuthService();
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _authService.isAdmin().then((value) {
      if (!mounted) return;
      setState(() => _isAdmin = value);
    }).catchError((_) {});
  }

  /// Drawer band karke nayi screen kholta hai.
  void _open(Widget screen) {
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.cream,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------------- HEADER ----------------
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: AppColors.goldGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gold.withOpacity(0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.diamond_outlined, color: AppColors.black, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'सूरपाटणे ज्वेलर्स',
                          style: AppText.heading.copyWith(
                            color: AppColors.black,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Trust. Purity. Elegance.',
                          style: TextStyle(
                            color: AppColors.charcoal.withOpacity(0.55),
                            fontSize: 11.5,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: AppColors.gold.withOpacity(0.3)),

            // ---------------- MENU ----------------
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 90),
                children: [
                  _DrawerItem(
                    icon: Icons.auto_awesome,
                    title: 'राशि और रत्न',
                    subtitle: 'अपनी राशि का रत्न व जानकारी देखें',
                    onTap: () => _open(const RashiScreen()),
                  ),

                  if (_isAdmin) ...[
                    const SizedBox(height: 22),
                    const GoldSectionTitle(title: 'ADMIN'),

                    const _GroupLabel('ADS'),
                    _DrawerItem(
                      icon: Icons.campaign_outlined,
                      title: 'Ads Banner Manage',
                      subtitle: 'Home screen ka ad banner on/off aur images',
                      onTap: () => _open(const ManageAdsScreen()),
                    ),
                    _DrawerItem(
                      icon: Icons.ad_units_outlined,
                      title: 'Big Ad Manage',
                      subtitle: 'App kholte hi dikhne wala bada ad',
                      onTap: () => _open(const ManageBigAdScreen()),
                    ),

                    const _GroupLabel('INVESTMENT & SIP'),
                    _DrawerItem(
                      icon: Icons.account_balance_outlined,
                      title: 'Investment Manage',
                      subtitle: 'SIP aur Quick Buy on/off karo',
                      onTap: () => _open(const ManageInvestmentScreen()),
                    ),
                    _DrawerItem(
                      icon: Icons.table_chart_outlined,
                      title: 'Investment Report',
                      subtitle: 'Kisne kitna invest kiya, poori list',
                      onTap: () => _open(const AdminInvestmentReportScreen()),
                    ),
                    _DrawerItem(
                      icon: Icons.assignment_ind_outlined,
                      title: 'Naya SIP Form',
                      subtitle: 'Customer ka SIP form, code aur PDF',
                      onTap: () => _open(const AdminSipFormScreen()),
                    ),
                    _DrawerItem(
                      icon: Icons.calendar_month_outlined,
                      title: 'SIP Report',
                      subtitle: 'Mahine ka hisab, baaki, SIP band karo',
                      onTap: () => _open(const AdminSipReportScreen()),
                    ),

                    const _GroupLabel('GIRVI'),
                    _DrawerItem(
                      icon: Icons.receipt_long_outlined,
                      title: 'Girvi Bills',
                      subtitle: 'Naya bill banao, purane dekho/manage karo',
                      onTap: () => _open(const AdminGirviListScreen()),
                    ),

                    const _GroupLabel('MESSAGES'),
                    _DrawerItem(
                      icon: Icons.notifications_active_outlined,
                      title: 'Notification Bhejo',
                      subtitle: 'Sabhi customers ko app me message bhejo',
                      onTap: () => _open(const AdminSendNotificationScreen()),
                    ),
                    _DrawerItem(
                      icon: Icons.share_outlined,
                      title: 'Rate WhatsApp pe bhejo',
                      subtitle: 'Aaj ka bhav group me share karo',
                      onTap: () {
                        final rootCtx = Navigator.of(context, rootNavigator: true).context;
                        Navigator.of(context).pop();
                        openRateShare(rootCtx);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// GROUP LABEL
// =====================================================================

class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.goldDark,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

// =====================================================================
// DRAWER ITEM (safed card, sone-rang ka border)
// =====================================================================

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.gold.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.13),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: AppColors.goldDark, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.charcoal,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.charcoal.withOpacity(0.5),
                          fontSize: 10.5,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.goldDark.withOpacity(0.55),
                  size: 13,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}