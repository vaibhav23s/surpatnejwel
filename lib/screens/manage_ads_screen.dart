import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/ad_banner_service.dart';

class ManageAdsScreen extends StatefulWidget {
  const ManageAdsScreen({super.key});

  @override
  State<ManageAdsScreen> createState() => _ManageAdsScreenState();
}

class _ManageAdsScreenState extends State<ManageAdsScreen> {
  final _adService = AdBannerService();
  final _picker = ImagePicker();
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 65,
      );
      if (picked == null) return;
      setState(() => _uploading = true);
      final bytes = await picked.readAsBytes();
      await _adService.addUploadedImage(bytes);
      messenger.showSnackBar(const SnackBar(content: Text('Image add ho gayi')));
    } on AdBannerException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Image add nahi hui: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _remove(AdBannerItem item) async {
    if (item.isUploaded) {
      await _adService.removeUploadedImage(item.id!);
    } else {
      await _adService.removeImageUrl(item.value);
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
        title: Text('Ads Banner Manage Karo', style: AppText.heading.copyWith(fontSize: 18)),
      ),
      body: StreamBuilder<AdBannerConfig>(
        stream: _adService.watchConfig(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Load nahi ho paya. Firestore rules check karo (shop/adBanner aur shop/adBanner/images).\n\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: AppText.bodyMuted.copyWith(fontSize: 12),
                ),
              ),
            );
          }
          final config = snapshot.data ?? const AdBannerConfig(enabled: false);
          final uploadedCount = config.items.where((e) => e.isUploaded).length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                            Text('Ads Banner',
                                style: AppText.body.copyWith(fontWeight: FontWeight.w600, fontSize: 15)),
                            const SizedBox(height: 3),
                            Text(
                              config.enabled
                                  ? 'Home screen pe sabko dikh raha hai'
                                  : 'Band hai — customers ko nahi dikhega',
                              style: AppText.bodyMuted.copyWith(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: config.enabled,
                        activeColor: AppColors.gold,
                        onChanged: (v) => _adService.setEnabled(v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _uploading ? null : _pickAndUpload,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(_uploading ? 'Upload ho rahi hai...' : 'Gallery se image chuno'),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Chaudi (wide) image sabse achhi dikhti hai, jaise 1200 x 400. '
                      'Maximum ${AdBannerService.maxUploaded} images ($uploadedCount lagi hain).',
                  style: AppText.bodyMuted.copyWith(fontSize: 11.5, height: 1.4),
                ),
                const SizedBox(height: 22),
                Text(
                  'Abhi ke images (${config.items.length})',
                  style: AppText.body.copyWith(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 12),
                if (config.items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'Abhi tak koi image nahi hai. Upar button se gallery me se chuno.',
                      style: AppText.bodyMuted.copyWith(fontSize: 12.5),
                    ),
                  )
                else
                  ...config.items.map((item) => _ImageRow(item: item, onDelete: () => _remove(item))),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ImageRow extends StatelessWidget {
  final AdBannerItem item;
  final VoidCallback onDelete;
  const _ImageRow({required this.item, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final bytes = adImageBytes(item.value);
    final broken = Container(
      width: 96,
      height: 70,
      color: AppColors.black,
      child: Icon(Icons.broken_image_outlined, color: AppColors.gold.withOpacity(0.5), size: 20),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.charcoal,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: bytes != null
                ? Image.memory(bytes,
                width: 96, height: 70, fit: BoxFit.cover, errorBuilder: (_, __, ___) => broken)
                : Image.network(item.value,
                width: 96, height: 70, fit: BoxFit.cover, errorBuilder: (_, __, ___) => broken),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.isUploaded ? 'Phone se upload ki hui' : 'Purana link wala image',
              style: AppText.bodyMuted.copyWith(fontSize: 12),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}