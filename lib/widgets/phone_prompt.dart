import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';

/// Asks a logged-in user for their mobile number if their profile
/// doesn't have one yet (older accounts made before signup collected
/// it). Shows at most once per app launch, and "Baad me" just closes it.
/// The number is saved to users/{uid}.phone — same field the Profile
/// screen's "Personal Information" sheet edits.
class PhonePrompt {
  static bool _askedThisSession = false;

  static Future<void> checkAndAsk(BuildContext context) async {
    if (_askedThisSession) return;
    final profile = await UserService().getProfile();
    if (profile == null || profile.phone.isNotEmpty) return;
    if (!context.mounted) return;
    _askedThisSession = true;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PhoneSheet(),
    );
  }
}

class _PhoneSheet extends StatefulWidget {
  const _PhoneSheet();

  @override
  State<_PhoneSheet> createState() => _PhoneSheetState();
}

class _PhoneSheetState extends State<_PhoneSheet> {
  final _ctrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // Grab the messenger before the sheet closes; using this sheet's
    // own context after Navigator.pop causes the red-screen assertion.
    final messenger = ScaffoldMessenger.of(context);
    final phone = _ctrl.text.trim();
    if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(phone)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Sahi 10 digit mobile number daalo')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await UserService().updateProfile(phone: phone);
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Mobile number save ho gaya')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text('Save nahi hua: $e')));
    }
  }

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: AppColors.gold.withOpacity(.12), shape: BoxShape.circle),
                  child: const Icon(Icons.phone_outlined, color: AppColors.goldDark),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Mobile number add karo',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.charcoal),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Girvi ki reminder aur zaroori updates WhatsApp pe bhejne ke liye aapka number chahiye.',
              style: TextStyle(fontSize: 12.5, color: Colors.black54, height: 1.4),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _ctrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
              decoration: InputDecoration(
                hintText: '10 digit mobile number',
                prefixIcon: const Icon(Icons.phone_outlined),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.charcoal,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _saving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : const Text('Save Karo', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
            Center(
              child: TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('Baad me', style: TextStyle(color: Colors.black45)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}