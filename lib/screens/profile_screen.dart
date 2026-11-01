import 'package:flutter/material.dart';

import 'package:surpatne_jewellers/screens/rashe_screen.dart';
import 'customer_girvi_screen.dart';
import 'my_sip_screen.dart';
import 'info_screens.dart';
import 'notifications_screen.dart';

import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/bottom_nav.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/investment_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _userService = UserService();
  final _investmentService = InvestmentService();

  // ===============================================================
  // EDIT PERSONAL INFORMATION
  // ===============================================================

  Future<void> _showEditPersonalInfo(UserProfile? profile) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditPersonalInfoSheet(
        profile: profile,
        userService: _userService,
      ),
    );
    if (mounted) setState(() {});
  }

  // ===============================================================
  // LOGOUT
  // ===============================================================

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.cream,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Text(
            'Logout?',
            style: TextStyle(color: AppColors.charcoal, fontWeight: FontWeight.w800),
          ),
          content: const Text(
            'Are you sure you want to sign out from your account?',
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.charcoal)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) return;

    await _authService.signOut();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  // ===============================================================
  // DELETE ACCOUNT
  // ===============================================================

  Future<void> _deleteAccount() async {
    final pwdCtrl = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Delete account?',
            style: TextStyle(color: AppColors.charcoal, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your profile and login will be permanently deleted. This cannot be undone. '
              'Purchase and SIP/girvi records that the shop must keep by law may be retained.',
              style: TextStyle(color: Colors.black54, fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pwdCtrl,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Enter your password to confirm',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.charcoal))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, pwdCtrl.text),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent, foregroundColor: Colors.white, elevation: 0),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    pwdCtrl.dispose();
    if (password == null || password.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await _authService.deleteAccount(password);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } on AuthException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not delete account. Please try again.')));
    }
  }

  // ===============================================================
  // BUILD
  // ===============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: AppColors.cream,
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),

                      // TOP BAR (home jaisa)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          GoldCircleIcon(
                            icon: Icons.arrow_back_rounded,
                            onTap: () {
                              final scope = SJNavScope.maybeOf(context);
                              if (scope != null) {
                                scope.switchTab(0);
                              } else {
                                Navigator.of(context).maybePop();
                              }
                            },
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                'My Profile',
                                style: AppText.heading.copyWith(
                                  color: AppColors.black,
                                  fontSize: 19,
                                ),
                              ),
                            ),
                          ),
                          const NotificationBell(),
                        ],
                      ),

                      const SizedBox(height: 20),

                      StreamBuilder<UserProfile?>(
                        stream: _userService.watchProfile(),
                        builder: (context, snapshot) {
                          final profile = snapshot.data;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _PremiumProfileCard(
                                profile: profile,
                                onEdit: () => _showEditPersonalInfo(profile),
                              ),

                              const SizedBox(height: 26),

                              // MY HOLDINGS
                              const GoldSectionTitle(title: 'MY HOLDINGS'),
                              const SizedBox(height: 14),
                              StreamBuilder<InvestmentHolding>(
                                stream: _investmentService.watchHoldings(),
                                builder: (context, hs) {
                                  final h = hs.data ??
                                      const InvestmentHolding(goldGrams: 0, silverGrams: 0);
                                  return Row(
                                    children: [
                                      Expanded(
                                        child: _HoldTile(
                                          label: 'Gold balance',
                                          grams: h.goldGrams,
                                          gold: true,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: _HoldTile(
                                          label: 'Silver balance',
                                          grams: h.silverGrams,
                                          gold: false,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Gold and silver bought through Quick Buy',
                                style: TextStyle(
                                  color: AppColors.charcoal.withOpacity(0.5),
                                  fontSize: 11,
                                ),
                              ),

                              const SizedBox(height: 26),

                              // ACCOUNT
                              const GoldSectionTitle(title: 'ACCOUNT'),
                              const SizedBox(height: 14),

                              _AccountMenuCard(
                                children: [
                                  _AccountMenuItem(
                                    icon: Icons.person_outline_rounded,
                                    title: 'Personal Information',
                                    subtitle: 'Edit your name, mobile number and PAN',
                                    onTap: () => _showEditPersonalInfo(profile),
                                  ),
                                  const _AccountMenuDivider(),
                                  _AccountMenuItem(
                                    icon: Icons.savings_outlined,
                                    title: 'My SIP',
                                    subtitle: 'Enter your code to see paid and pending instalments',
                                    onTap: () => openMySip(context),
                                  ),
                                  const _AccountMenuDivider(),
                                  _AccountMenuItem(
                                    icon: Icons.receipt_long_outlined,
                                    title: 'Girvi Section',
                                    subtitle: 'View full details of your pawned items',
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => const CustomerGirviScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                  const _AccountMenuDivider(),
                                  _AccountMenuItem(
                                    icon: Icons.auto_awesome,
                                    title: 'Rashi Gemstones',
                                    subtitle: 'Find the gemstone for your zodiac sign',
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(builder: (_) => RashiScreen()),
                                      );
                                    },
                                  ),
                                  const _AccountMenuDivider(),
                                  _AccountMenuItem(
                                    icon: Icons.notifications_none_rounded,
                                    title: 'Notifications',
                                    subtitle: 'Messages and daily rates from the shop',
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => const NotificationsScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                  const _AccountMenuDivider(),
                                  _AccountMenuItem(
                                    icon: Icons.headset_mic_outlined,
                                    title: 'Help & Support',
                                    subtitle: 'Call or WhatsApp the shop',
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => const HelpSupportScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                  const _AccountMenuDivider(),
                                  _AccountMenuItem(
                                    icon: Icons.shield_outlined,
                                    title: 'Privacy Policy',
                                    subtitle: 'About this app and how your data is handled',
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => const PrivacyPolicyScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),

                              const SizedBox(height: 18),

                              _LogoutButton(onTap: _logout),

                              const SizedBox(height: 12),

                              Center(
                                child: TextButton.icon(
                                  onPressed: _deleteAccount,
                                  icon: const Icon(Icons.delete_forever_outlined,
                                      color: Colors.black45, size: 18),
                                  label: const Text('Delete my account',
                                      style: TextStyle(color: Colors.black45, fontSize: 12.5)),
                                ),
                              ),

                              const SizedBox(height: 20),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// COMMON CARD LOOK (Investment screen jaisa)
// =====================================================================

BoxDecoration _cardDecoration({double radius = 20}) => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: AppColors.gold.withOpacity(0.3)),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ],
);

// =====================================================================
// PROFILE CARD
// =====================================================================

class _PremiumProfileCard extends StatelessWidget {
  final UserProfile? profile;
  final VoidCallback? onEdit;

  const _PremiumProfileCard({
    required this.profile,
    this.onEdit,
  });

  String _maskPan(String pan) {
    if (pan.length < 10) return pan;
    return '${pan.substring(0, 5)}****${pan.substring(9)}';
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Icon(icon, color: AppColors.goldDark, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.charcoal.withOpacity(0.78),
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = profile?.name.isNotEmpty == true ? profile!.name : 'Your Name';
    final phone = profile?.phone.isNotEmpty == true ? profile!.phone : 'Add your mobile number';
    final email = profile?.email ?? '';
    final pan = profile?.pan ?? '';

    String avatarLetter = 'S';
    if (name.trim().isNotEmpty && name.trim() != 'Your Name') {
      avatarLetter = name.trim()[0].toUpperCase();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(radius: 24),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.goldGradient,
                  boxShadow: [
                    BoxShadow(color: AppColors.gold.withOpacity(0.3), blurRadius: 14),
                  ],
                ),
                child: Center(
                  child: Text(
                    avatarLetter,
                    style: const TextStyle(
                      color: AppColors.black,
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.charcoal,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.gold.withOpacity(0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.workspace_premium_outlined,
                              color: AppColors.goldDark, size: 14),
                          SizedBox(width: 5),
                          Text(
                            'SJ Premium Member',
                            style: TextStyle(
                              color: AppColors.goldDark,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              GoldCircleIcon(icon: Icons.edit_outlined, onTap: onEdit),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: AppColors.gold.withOpacity(0.2)),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow(Icons.phone_outlined, phone),
                if (email.isNotEmpty) _infoRow(Icons.email_outlined, email),
                if (pan.isNotEmpty) _infoRow(Icons.badge_outlined, 'PAN: ${_maskPan(pan)}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// HOLDING TILE
// =====================================================================

class _HoldTile extends StatelessWidget {
  final String label;
  final double grams;
  final bool gold;

  const _HoldTile({
    required this.label,
    required this.grams,
    required this.gold,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: gold
                      ? AppColors.goldGradient
                      : const LinearGradient(colors: [Color(0xFFB8B8B8), Color(0xFFE8E8E8)]),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.charcoal.withOpacity(0.6),
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${grams.toStringAsFixed(4)} g',
            style: const TextStyle(
              color: AppColors.charcoal,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// ACCOUNT MENU CARD
// =====================================================================

class _AccountMenuCard extends StatelessWidget {
  final List<Widget> children;

  const _AccountMenuCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(radius: 22),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(children: children),
      ),
    );
  }
}

class _AccountMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AccountMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.goldDark, size: 20),
              ),
              const SizedBox(width: 13),
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
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.charcoal.withOpacity(0.5),
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppColors.goldDark.withOpacity(0.55),
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountMenuDivider extends StatelessWidget {
  const _AccountMenuDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 70, right: 15),
      child: Divider(
        height: 1,
        thickness: 0.7,
        color: AppColors.gold.withOpacity(0.18),
      ),
    );
  }
}

// =====================================================================
// LOGOUT
// =====================================================================

class _LogoutButton extends StatelessWidget {
  final VoidCallback onTap;

  const _LogoutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.055),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.red.withOpacity(0.18)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
              ),
              const SizedBox(width: 13),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Logout',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Sign out from your account',
                      style: TextStyle(color: Colors.black45, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.redAccent, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

// ===============================================================
// EDIT PERSONAL INFORMATION — bottom sheet
// ===============================================================

class _EditPersonalInfoSheet extends StatefulWidget {
  final UserProfile? profile;
  final UserService userService;

  const _EditPersonalInfoSheet({
    required this.profile,
    required this.userService,
  });

  @override
  State<_EditPersonalInfoSheet> createState() => _EditPersonalInfoSheetState();
}

class _EditPersonalInfoSheetState extends State<_EditPersonalInfoSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _panController;
  bool _isSaving = false;

  static final RegExp _panFormat = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$');

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile?.name ?? '');
    _phoneController = TextEditingController(text: widget.profile?.phone ?? '');
    _panController = TextEditingController(text: widget.profile?.pan ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _panController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final pan = _panController.text.trim().toUpperCase();

    if (name.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Please enter your name')));
      return;
    }

    if (phone.length != 10 || !RegExp(r'^[0-9]+$').hasMatch(phone)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please enter a valid 10 digit mobile number')),
      );
      return;
    }

    if (pan.isNotEmpty && !_panFormat.hasMatch(pan)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('PAN format is not valid (example: ABCDE1234F)')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await widget.userService.updateProfile(
        name: name,
        phone: phone,
        pan: pan.isEmpty ? null : pan,
      );

      if (!mounted) return;
      Navigator.pop(context);

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);

      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to update profile: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  InputDecoration _dec(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon),
    counterText: '',
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  );

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      t,
      style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.charcoal),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
        decoration: const BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit_outlined, color: AppColors.goldDark),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Personal Information',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.charcoal,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _label('Full Name'),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: _dec('Enter your name', Icons.person_outline),
              ),
              const SizedBox(height: 18),

              _label('Mobile Number'),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                decoration: _dec('Enter 10 digit mobile number', Icons.phone_outlined),
              ),
              const SizedBox(height: 18),

              _label('PAN Number (optional)'),
              TextField(
                controller: _panController,
                textCapitalization: TextCapitalization.characters,
                maxLength: 10,
                decoration: _dec('ABCDE1234F', Icons.badge_outlined),
              ),
              const SizedBox(height: 6),
              Text(
                'PAN is required for a single purchase of Rs. 2,00,000 or more.',
                style: TextStyle(color: AppColors.charcoal.withOpacity(0.5), fontSize: 11),
              ),
              const SizedBox(height: 22),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.charcoal,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                      : const Text(
                    'Save Changes',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}