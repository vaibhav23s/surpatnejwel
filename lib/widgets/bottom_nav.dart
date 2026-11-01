import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class NavItemData {
  final IconData icon;
  final String label;
  const NavItemData(this.icon, this.label);
}

final List<NavItemData> kNavItems = [
  const NavItemData(Icons.diamond_outlined, 'Home',),
  const NavItemData(Icons.show_chart, 'Rates'),
  NavItemData(Icons.account_balance, 'Investment'),
  const NavItemData(Icons.person_outline, 'Profile'),
];

/// MainShell ke andar ke saare tabs ko ye scope milta hai.
/// Isse (1) tab screens ke andar bacha hua koi purana SJBottomNav apne aap
/// hide ho jata hai (duplicate nav nahi dikhega), aur (2) koi bhi screen
/// `SJNavScope.maybeOf(context)?.switchTab(i)` se tab badal sakti hai.
class SJNavScope extends InheritedWidget {
  final ValueChanged<int> switchTab;
  const SJNavScope({
    super.key,
    required this.switchTab,
    required super.child,
  });

  static SJNavScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SJNavScope>();

  @override
  bool updateShouldNotify(SJNavScope oldWidget) => false;
}

/// Floating, rounded, glassy bottom navigation bar.
/// Sits above the content with margin on all sides so it never
/// overlaps/hides the screen content underneath.
class SJBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;
  const SJBottomNav({
    super.key,
    required this.currentIndex,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Shell ke tab ke andar ho to duplicate nav mat dikhao.
    if (SJNavScope.maybeOf(context) != null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: AppColors.black.withOpacity(0.35),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: AppColors.gold.withOpacity(0.35)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(kNavItems.length, (i) {
                final item = kNavItems[i];
                final active = i == currentIndex;
                return InkWell(
                  onTap: () => onTap?.call(i),
                  borderRadius: BorderRadius.circular(24),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: active ? AppColors.goldGradient : null,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.icon,
                          color: active ? AppColors.black : AppColors.cream.withOpacity(0.75),
                          size: 20,
                        ),
                        if (active) ...[
                          const SizedBox(width: 6),
                          Text(
                            item.label,
                            style: const TextStyle(
                              color: AppColors.black,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}