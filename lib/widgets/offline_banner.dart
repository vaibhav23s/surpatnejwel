import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/app_errors.dart';

/// Net band hone par upar chhota "No internet" pill dikhata hai.
/// Koi extra package nahi chahiye: har kuch second me asli internet check hota hai.
class OfflineBanner extends StatefulWidget {
  final Widget child;
  const OfflineBanner({super.key, required this.child});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> with WidgetsBindingObserver {
  Timer? _timer;
  bool _offline = false;
  bool _checking = false;

  Future<void> _check() async {
    if (_checking) return;
    _checking = true;
    try {
      final online = await Net.isOnline();
      if (mounted && _offline == online) {
        setState(() => _offline = !online);
      }
    } finally {
      _checking = false;
    }
  }

  void _start() {
    _timer?.cancel();
    _check();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) => _check());
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  // App background me ho to check band, wapas aate hi dobara shuru.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _start();
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: SafeArea(
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 250),
                offset: _offline ? Offset.zero : const Offset(0, -2),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: _offline ? 1 : 0,
                  child: Center(
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3A3A3A),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.wifi_off_rounded, color: Colors.white, size: 15),
                            SizedBox(width: 7),
                            Text(
                              'No internet connection',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}