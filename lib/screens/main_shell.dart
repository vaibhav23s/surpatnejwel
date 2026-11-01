import 'package:flutter/material.dart';
import 'market_rate_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';
import 'home_screen.dart';
import 'investment_screen.dart';
import 'profile_screen.dart';

/// Ek hi Scaffold jisme 4 tabs + floating bottom nav hai.
/// Nav bar har tab par rehta hai, Navigator.push nahi hota, isliye
/// Profile se seedha Rates/Investment/Home par ja sakte ho.
class MainShell extends StatefulWidget {
  final int initialIndex;
  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index = widget.initialIndex;

  // Tabs tabhi build hote hain jab pehli baar khulte hain (lazy),
  // aur baad me IndexedStack unka state (scroll position etc.) bacha ke rakhta hai.
  late final Set<int> _built = {widget.initialIndex};

  Widget _tab(int i) {
    switch (i) {
      case 0:
        return const HomeTab();
      case 1:
        return const RateHistoryScreen();
      case 2:
        return const InvestmentScreen();
      default:
        return const ProfileScreen();
    }
  }

  void _switchTab(int i) {
    if (i == _index) return;
    setState(() {
      _index = i;
      _built.add(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Kisi aur tab par ho to back dabane par app band hone ki jagah Home par aao.
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _switchTab(0);
      },
      child: Scaffold(
        backgroundColor: AppColors.cream,
        body: Stack(
          children: [
            Positioned.fill(
              child: SJNavScope(
                switchTab: _switchTab,
                child: IndexedStack(
                  index: _index,
                  children: List.generate(
                    4,
                        (i) => _built.contains(i) ? _tab(i) : const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: SJBottomNav(currentIndex: _index, onTap: _switchTab),
              ),
            ),
          ],
        ),
      ),
    );
  }
}