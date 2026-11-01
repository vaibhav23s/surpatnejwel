import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/big_ad_dialog.dart';
import '../services/big_ad_service.dart';

class ManageBigAdScreen extends StatefulWidget {
  const ManageBigAdScreen({super.key});

  @override
  State<ManageBigAdScreen> createState() => _ManageBigAdScreenState();
}

class _ManageBigAdScreenState extends State<ManageBigAdScreen> {
  final _service = BigAdService();
  final _picker = ImagePicker();
  late final Stream<BigAdConfig> _stream = _service.watch();
  bool _busy = false;

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _pick() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        imageQuality: 70,
      );
      if (picked == null) return;
      setState(() => _busy = true);
      final bytes = await picked.readAsBytes();
      await _service.setImage(bytes);
      _snack('Ad image lag gayi');
    } on BigAdException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('Image nahi lagi: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggle(bool value, BigAdConfig cfg) async {
    if (value && !cfg.hasImage) {
      _snack('Pehle ad ki image lagao');
      return;
    }
    try {
      await _service.setEnabled(value);
    } catch (e) {
      _snack('Badal nahi paya: $e');
    }
  }

  Future<void> _remove() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.charcoal,
        title: Text('Image hatani hai?', style: AppText.heading.copyWith(fontSize: 17)),
        content: Text('Image hat jayegi aur ad band ho jayega.',
            style: AppText.bodyMuted.copyWith(fontSize: 12.5)),
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
      await _service.removeImage();
    } catch (e) {
      _snack('Hata nahi paya: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.gold),
        title: Text('Big Ad Manage Karo', style: AppText.heading.copyWith(fontSize: 18)),
      ),
      body: StreamBuilder<BigAdConfig>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Load nahi ho paya. Firestore rules me shop/bigAd check karo.\n\n${snap.error}',
                  textAlign: TextAlign.center,
                  style: AppText.bodyMuted.copyWith(fontSize: 12),
                ),
              ),
            );
          }
          final cfg = snap.data ?? const BigAdConfig(enabled: false);
          final bytes = cfg.bytes;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- toggle ---
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.charcoal,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Big Ad',
                                style: AppText.body.copyWith(fontWeight: FontWeight.w600, fontSize: 15)),
                            const SizedBox(height: 3),
                            Text(
                              cfg.enabled
                                  ? 'ON hai: app kholte hi customers ko dikhega'
                                  : 'OFF hai: kisi ko nahi dikhega',
                              style: AppText.bodyMuted.copyWith(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: cfg.enabled,
                        activeColor: AppColors.gold,
                        onChanged: (v) => _toggle(v, cfg),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // --- preview ---
                Text('Abhi ki ad image',
                    style: AppText.body.copyWith(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 10),
                if (bytes == null)
                  Container(
                    height: 160,
                    width: double.infinity,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.charcoal,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.gold.withOpacity(0.2)),
                    ),
                    child: Text('Abhi koi image nahi hai', style: AppText.bodyMuted.copyWith(fontSize: 12.5)),
                  )
                else
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 380),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.memory(bytes, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                const SizedBox(height: 18),

                GoldButton(
                  label: _busy
                      ? 'Lag rahi hai...'
                      : (bytes == null ? 'Gallery se image chuno' : 'Image badlo'),
                  onTap: _busy ? null : _pick,
                ),
                const SizedBox(height: 8),
                Text(
                  'Seedhi (portrait) image sabse achhi dikhti hai, jaise 1080 x 1350. '
                      'Size 650 KB se kam rakho. Image ke upar customer ko ❌ dikhega.',
                  style: AppText.bodyMuted.copyWith(fontSize: 11.5, height: 1.4),
                ),

                if (bytes != null) ...[
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.gold.withOpacity(0.6)),
                            minimumSize: const Size.fromHeight(46),
                          ),
                          onPressed: () => showBigAdDialog(context, bytes),
                          icon: const Icon(Icons.visibility_outlined, color: AppColors.gold, size: 18),
                          label: const Text('Preview', style: TextStyle(color: AppColors.gold)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.redAccent),
                            minimumSize: const Size.fromHeight(46),
                          ),
                          onPressed: _remove,
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                          label: const Text('Hatao', style: TextStyle(color: Colors.redAccent)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}