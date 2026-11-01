import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

const String _kSeenKey = 'onboarding_seen_v1';

/// Yahan apni images ke naam likho. Kam ya zyada kar sakte ho.
const List<String> kOnboardingImages = [
  'assets/onboarding/1.png',
  'assets/onboarding/2.png',
  'assets/onboarding/3.png',
];

class OnboardingScreen extends StatefulWidget {
  /// Onboarding ke baad ye screen khulegi (jaise LoginScreen).
  final Widget next;
  const OnboardingScreen({super.key, required this.next});

  /// main.dart me check karne ke liye: pehle kabhi dikhayi gayi ya nahi.
  static Future<bool> hasSeen() async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getBool(_kSeenKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markSeen() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kSeenKey, true);
    } catch (_) {}
  }
  /// Splash ke baad: pehli baar ho to onboarding dikhao, warna seedha [next].
  static Future<Widget> wrap(Widget next) async {
    final seen = await hasSeen();
    return seen ? next : OnboardingScreen(next: next);
  }
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  bool get _isLast => _page == kOnboardingImages.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await OnboardingScreen.markSeen();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => widget.next),
    );
  }

  void _nextPage() {
    if (_isLast) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        children: [
          // --- Images (poori screen) ---
          Positioned.fill(
            child: PageView.builder(
              controller: _controller,
              itemCount: kOnboardingImages.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) {
                return Image.asset(
                  kOnboardingImages[i],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.black,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Image nahi mili:\n${kOnboardingImages[i]}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                );
              },
            ),
          ),

          // --- Neeche halka kaala parda, taaki button aur dots saaf dikhein ---
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 210,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.55),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // --- Skip ---
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 14, 0),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _isLast ? 0 : 1,
                  child: TextButton(
                    onPressed: _isLast ? null : _finish,
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.black.withOpacity(0.35),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // --- Dots + button ---
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(kOnboardingImages.length, (i) {
                        final active = i == _page;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: active ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            gradient: active ? AppColors.goldGradient : null,
                            color: active ? null : Colors.white.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 18),
                    GoldButton(
                      label: _isLast ? 'Get Started' : 'Next',
                      onTap: _nextPage,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}