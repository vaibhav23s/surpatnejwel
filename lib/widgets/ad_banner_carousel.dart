import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/ad_banner_service.dart';
import '../theme/app_theme.dart';

class AdBannerCarousel extends StatefulWidget {
  final List<String> imageUrls;
  const AdBannerCarousel({super.key, required this.imageUrls});

  @override
  State<AdBannerCarousel> createState() => _AdBannerCarouselState();
}

class _AdBannerCarouselState extends State<AdBannerCarousel> {
  late final PageController _controller;
  Timer? _timer;
  int _page = 0;
  List<Uint8List?> _memory = const [];

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _decode();
    _startAutoScroll();
  }

  void _decode() {
    _memory = widget.imageUrls.map(adImageBytes).toList();
  }

  void _startAutoScroll() {
    _timer?.cancel();
    if (widget.imageUrls.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_controller.hasClients) return;
      _page = (_page + 1) % widget.imageUrls.length;
      _controller.animateToPage(
        _page,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void didUpdateWidget(covariant AdBannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.imageUrls, widget.imageUrls)) {
      _decode();
      if (_page >= widget.imageUrls.length) _page = 0;
      _startAutoScroll();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Widget _broken() => Container(
    color: AppColors.charcoal,
    alignment: Alignment.center,
    child: Icon(Icons.image_not_supported_outlined, color: AppColors.gold.withOpacity(0.5)),
  );

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: 200,
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.imageUrls.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) {
                final bytes = i < _memory.length ? _memory[i] : null;
                if (bytes != null) {
                  return Image.memory(
                    bytes,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => _broken(),
                  );
                }
                return Image.network(
                  widget.imageUrls[i],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (_, __, ___) => _broken(),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: AppColors.charcoal,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2),
                    );
                  },
                );
              },
            ),
          ),
        ),
        if (widget.imageUrls.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.imageUrls.length, (i) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _page ? AppColors.gold : AppColors.gold.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}