import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/price_card.dart';
import '../widgets/collection_card.dart';
import '../widgets/rashifal_drawer.dart';
import '../widgets/ad_banner_carousel.dart';
import '../services/rate_store.dart';
import '../services/ad_banner_service.dart';
import '../services/auth_service.dart';
import '../utils/currency_format.dart';
import 'main_shell.dart';
import 'update_rate_screen.dart';
import 'notifications_screen.dart';
import '../widgets/rate_share_sheet.dart';
import '../widgets/big_ad_dialog.dart';

/// App ka entry point. Ab ye sirf MainShell (persistent bottom nav) kholta hai,
/// isliye login/splash/main.dart me `HomeScreen()` ko change karne ki zarurat nahi.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => const MainShell();
}

// ============================================================
// COLLECTION DATA
// Naya card jodna ho to neeche kisi row me ek line likh do.
//   _Item(card ka naam, card ki image, [detail page ka naam], [detail page ki image])
// Detail wale dono optional hain; na likho to card wale hi use hote hain.
// ============================================================

class _Item {
  final String title;
  final String image;
  final String? detailTitle;
  final String? detailImage;
  const _Item(this.title, this.image, {this.detailTitle, this.detailImage});
}

const List<List<_Item>> _collectionRows = [
  // Row 1 - Silver murti / pooja
  [
    _Item('Laxmi Mata Silver', 'assets/collection/laxmi.png'),
    _Item('Laxmi & Ganesh Ji Silver', 'assets/collection/ganu__laxmidevi.png'),
    _Item('Khanderao', 'assets/collection/khanderav.png'),
    _Item('Paduka', 'assets/collection/paduka.png'),
    _Item('Buddha Silver', 'assets/collection/budha.png'),
  ],
  // Row 2 - Mangalsutra
  [
    _Item('Designer Mangalsutra', 'assets/collection/mnglesutra_1.png'),
    _Item('Premium Design Mangalsutra', 'assets/collection/mnglesutra_2.png'),
    _Item('Catory Mangalsutra', 'assets/collection/mnglesutra_3.png'),
    _Item('Premium Mangalsutra', 'assets/collection/mnglesutra_4.png'),
    _Item('Designer Catory Mangalsutra', 'assets/collection/mnglesutra_5.png'),
  ],
  // Row 3 - Rings
  [
    _Item('Heart Ring', 'assets/collection/ring1.png'),
    _Item('Premium Ring', 'assets/collection/ring2.png'),
    _Item('Leaf Ring', 'assets/collection/ring3.png'),
    _Item('Marriage Heart Ring', 'assets/collection/ring4.png'),
    _Item('Premium Rings', 'assets/collection/ring5.png'),
  ],
  // Row 4 - Rings / Kda
  [
    _Item('Rajmudra Ring', 'assets/collection/ring6.png'),
    _Item('Pure Gundi Kda', 'assets/collection/kda1.png'),
    _Item('Diamond Ring', 'assets/collection/ring7.png'),
    _Item('Aesthetic Ring', 'assets/collection/ring8.png'),
    _Item('Premium Kasav Anguthi', 'assets/collection/ring9.png'),
  ],
  // Row 5 - Kda
  [
    _Item('Pure Gundi Kda', 'assets/collection/kda3.png'),
    _Item('Pure Gundi Kda', 'assets/collection/kda2.png'),
    _Item('Pure Gundi Kda', 'assets/collection/kda4.png'),
    _Item('Pure Gundi Kda', 'assets/collection/kda5.png'),
    _Item('Pure Gundi Kda', 'assets/collection/kda6.png'),
  ],
  // Row 6 - Chains
  [
    _Item('Gold Chain', 'assets/collection/chane1.png'),
    _Item('Gold Chain', 'assets/collection/chane2.png'),
    _Item('Gold Chain', 'assets/collection/chane3.png'),
    _Item('Gold Chain', 'assets/collection/chane4.png'),
    _Item('Gold Chain', 'assets/collection/chane5.png',
        detailImage: 'assets/collection/chane5_1.png'),
    _Item('Gold Chain', 'assets/collection/chane6.png',
        detailImage: 'assets/collection/chane6_1.png'),
  ],
  // Row 7 - Pendants
  [
    _Item('Gold Pendant', 'assets/pandent_collection/pandent1.png'),
    _Item('Gold Pendant', 'assets/pandent_collection/pandent2.png'),
    _Item('Gold Pendant', 'assets/pandent_collection/pandent3.png'),
    _Item('Gold Pendant', 'assets/pandent_collection/pandent4.png'),
    _Item('Gold Pendant', 'assets/pandent_collection/pandent5.png'),
  ],
];

/// Home tab ka asli content (pehle ka HomeScreen). Bottom nav ab MainShell me hai.
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  // --- Today's rate, synced live from Firestore (shop/rates) ---
  final RateStore _rateStore = RateStore();
  StreamSubscription<DailyRates>? _ratesSub;
  DailyRates? _rates;
  bool _ratesLoading = true;

  // --- Whether this logged-in user can edit today's rate ---
  final AuthService _authService = AuthService();
  bool _isAdmin = false;

  // --- Home screen ad banner, admin-toggled ---
  final AdBannerService _adBannerService = AdBannerService();

  @override
  void initState() {
    super.initState();
    _ratesSub = _rateStore.watchRates().listen((rates) {
      if (!mounted) return;
      setState(() {
        _rates = rates;
        _ratesLoading = false;
      });
    });
    _authService.isAdmin().then((value) {
      if (!mounted) return;
      setState(() => _isAdmin = value);
    }).catchError((_) {});
    // Big Ad: home khulne ke thodi der baad
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) showBigAdIfNeeded(context);
    });
  }

  @override
  void dispose() {
    _ratesSub?.cancel();
    super.dispose();
  }

  Future<void> _openUpdateRate() async {
    final beforeGold = _rates?.gold10gInr;
    final beforeSilver = _rates?.silverKgInr;

    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const UpdateRateScreen()),
    );

    // Firestore stream ko naya rate laane ka thoda time do
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    final r = _rates;
    if (r == null) return;
    if (r.gold10gInr != beforeGold || r.silverKgInr != beforeSilver) {
      showRateShareSheet(context, r);
    }
  }

  /// Change vs the previously saved rate. Shows "Updated" until there
  /// are two saved values to compare (e.g. right after first install).
  ({String text, bool isPositive}) _changeFor(double? current, double? previous) {
    if (current == null) return (text: '—', isPositive: true);
    if (previous == null || previous == 0) return (text: 'Updated', isPositive: true);
    final diff = current - previous;
    final pct = (diff / previous) * 100;
    final sign = diff >= 0 ? '+' : '';
    return (
    text: '$sign${formatInr(diff)} ($sign${pct.toStringAsFixed(2)}%)',
    isPositive: diff >= 0,
    );
  }

  void _openDetail(_Item item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CollectionDetailScreen(
          title: item.detailTitle ?? item.title,
          price: '',
          image: item.detailImage ?? item.image,
        ),
      ),
    );
  }

  /// Ek card. Poore card par kahin bhi dabane se detail page khulta hai.
  Widget _card(_Item item) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openDetail(item),
      child: CollectionCard(
        title: item.title,
        price: '',
        image: item.image,
        onExplore: () => _openDetail(item),
      ),
    );
  }

  Widget _row(List<_Item> items) {
    return SizedBox(
      height: 250,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: items.map(_card).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const RashifalDrawer(),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: AppColors.cream,
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Builder(
                      builder: (context) => GoldCircleIcon(
                        icon: Icons.menu,
                        onTap: () => Scaffold.of(context).openDrawer(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (_isAdmin)
                      GoldCircleIcon(icon: Icons.edit_outlined, onTap: _openUpdateRate)
                    else
                      const SizedBox(width: 42),
                    const Spacer(),
                    const NotificationBell(),
                  ],
                ),
                const SizedBox(height: 16),

                // --- Price cards ---
                Builder(builder: (context) {
                  final goldChange = _changeFor(
                    _rates?.gold10gInr,
                    _rates?.previousGold10gInr,
                  );
                  final silverChange = _changeFor(
                    _rates?.silverKgInr,
                    _rates?.previousSilverKgInr,
                  );
                  final goldPrice = _ratesLoading || _rates == null
                      ? 'Loading…'
                      : '₹${formatInr(_rates!.gold10gInr)}';
                  final silverPrice = _ratesLoading || _rates == null
                      ? 'Loading…'
                      : '₹${formatInr(_rates!.silverKgInr)}';
                  return Row(
                    children: [
                      Expanded(
                        child: PriceCard(
                          label: '24K GOLD',
                          purity: '99.9% Purity',
                          price: goldPrice,
                          unit: '1g',
                          change: goldChange.text,
                          isPositive: goldChange.isPositive,
                          isGold: true,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: PriceCard(
                          label: 'SILVER',
                          purity: '99.9% Purity',
                          price: silverPrice,
                          unit: '10g',
                          change: silverChange.text,
                          isPositive: silverChange.isPositive,
                          isGold: false,
                        ),
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 22),

                // --- Ad banner ---
                StreamBuilder<AdBannerConfig>(
                  stream: _adBannerService.watchConfig(),
                  builder: (context, snapshot) {
                    final config = snapshot.data;
                    if (config == null || !config.enabled || config.imageUrls.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 22),
                      child: AdBannerCarousel(imageUrls: config.imageUrls),
                    );
                  },
                ),

                const SizedBox(height: 4),
                const GoldSectionTitle(title: 'OUR COLLECTION'),
                const SizedBox(height: 16),

                // --- Collection rows ---
                for (int i = 0; i < _collectionRows.length; i++) ...[
                  if (i > 0) const SizedBox(height: 16),
                  _row(_collectionRows[i]),
                ],

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CollectionDetailScreen extends StatelessWidget {
  final String title;
  final String price;
  final String image;

  const CollectionDetailScreen({
    super.key,
    required this.title,
    required this.price,
    required this.image,
  });

  void _showWhatsAppOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(26),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 45,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              const SizedBox(height: 20),

              Text(
                'Contact Us on WhatsApp',
                style: TextStyle(
                  color: AppColors.charcoal,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'Choose a WhatsApp number',
                style: TextStyle(
                  color: AppColors.charcoal.withOpacity(0.6),
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 20),

              _whatsappOption(
                context,
                title: 'Surpatne Jewellers',
                number: '9356446941',
              ),

              const SizedBox(height: 12),

              _whatsappOption(
                context,
                title: 'Shop / Sales',
                number: '9403463733',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _whatsappOption(
      BuildContext context, {
        required String title,
        required String number,
      }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () async {
        Navigator.pop(context);

        final cleanNumber = number.replaceAll(RegExp(r'[^0-9]'), '');

        final message = '🙏 Namaste Surpatne Jewellers!\n\n'
            '✨ Mujhe "${this.title}" ke baare mein jankari chahiye.\n\n'
            '💎 Kya ye item shop par available hai?\n'
            '📋 Iske price, availability aur design ke baare mein '
            'thodi aur information denge?\n\n'
            'Thank you! 😊';

        final Uri whatsappUrl = Uri.parse(
          'https://wa.me/91$cleanNumber'
              '?text=${Uri.encodeComponent(message)}',
        );

        if (await canLaunchUrl(whatsappUrl)) {
          await launchUrl(
            whatsappUrl,
            mode: LaunchMode.externalApplication,
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFFF7EEDF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.gold.withOpacity(0.25),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.chat_rounded,
              color: Color(0xFF25D366),
              size: 28,
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppColors.charcoal,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '+91 $number',
                    style: TextStyle(
                      color: AppColors.charcoal.withOpacity(0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppColors.gold,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.charcoal,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: AppColors.charcoal,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // PRODUCT IMAGE CARD
            Container(
              width: double.infinity,
              height: 330,
              decoration: BoxDecoration(
                color: const Color(0xFFF1E6D2),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.gold.withOpacity(0.35),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  image,
                  width: double.infinity,
                  height: 330,
                  fit: BoxFit.cover,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // PRODUCT NAME
            Text(
              title,
              style: TextStyle(
                color: AppColors.charcoal,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 10),

            if (price.isNotEmpty)
              Text(
                price,
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),

            const SizedBox(height: 26),

            // DETAILS SECTION
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF7EEDF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.gold.withOpacity(0.22),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color: AppColors.gold,
                        size: 21,
                      ),
                      const SizedBox(width: 9),
                      Text(
                        'Product Details',
                        style: TextStyle(
                          color: AppColors.charcoal,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'Premium jewellery crafted with quality '
                        'materials and elegant finishing.',
                    style: TextStyle(
                      color: AppColors.charcoal.withOpacity(0.72),
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // WHATSAPP INFO
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF6ED),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFF25D366).withOpacity(0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.chat_rounded,
                    color: Color(0xFF25D366),
                    size: 25,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Interested in this item? Ask us about availability.',
                      style: TextStyle(
                        color: AppColors.charcoal,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // WHATSAPP BUTTON
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showWhatsAppOptions(context),
        backgroundColor: Colors.greenAccent,
        elevation: 0,
        child: const Icon(
          Icons.chat,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}