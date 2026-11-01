import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

const String _kShopPhone1 = '9356446941';
const String _kShopPhone2 = '9403463733';

// =====================================================================
// SHARED PAGE PIECES
// =====================================================================

class _PageScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _PageScaffold({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.goldDark),
        title: Text(
          title,
          style: AppText.heading.copyWith(color: AppColors.black, fontSize: 20),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 6, 22, 40),
          children: children,
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;
  const _Heading(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 26, bottom: 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.charcoal,
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Para extends StatelessWidget {
  final String text;
  const _Para(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.charcoal.withOpacity(0.8),
          fontSize: 13.5,
          height: 1.6,
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  final String? lead;
  final String text;
  const _Point(this.text, {this.lead});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9, left: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.gold,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  if (lead != null)
                    TextSpan(
                      text: '$lead ',
                      style: const TextStyle(
                        color: AppColors.charcoal,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  TextSpan(text: text),
                ],
              ),
              style: TextStyle(
                color: AppColors.charcoal.withOpacity(0.8),
                fontSize: 13.5,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// PRIVACY POLICY PAGE
// =====================================================================

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PageScaffold(
      title: 'Privacy Policy',
      children: [
        _Para('Last updated: October 2026'),

        _Heading('About This App'),
        _Para(
          'The Surpatne Jewellers app brings our shop to your phone. '
              'It shows the gold and silver rates set by the shop every day, our jewellery '
              'collection, gold and silver investment options, records of your girvi (pawn) '
              'items, rashi gemstone information and messages from the shop.',
        ),

        _Heading('How to Use the App'),
        _Point(
          'See today\'s gold rate (per 1 gram) and silver rate (per 10 grams), the '
              'shop banner and our jewellery collection. Tap any item to see its details and '
              'to ask the shop about it on WhatsApp.',
          lead: 'Home:',
        ),
        _Point(
          'Open the Rates tab to see how the shop\'s rates have changed over time.',
          lead: 'Rates:',
        ),
        _Point(
          'Choose gold or silver, enter an amount or the grams you want, and pay securely '
              'through Razorpay. Your balance in grams is shown on the Investment screen and in '
              'your Profile.',
          lead: 'Quick Buy:',
        ),
        _Point(
          'Visit the shop and fill in the SIP form. You will receive a 6 digit SIP code. '
              'On the Investment screen tap Get Start, enter your code and pay your monthly '
              'instalment. The plan runs for 12 months.',
          lead: 'Monthly SIP:',
        ),
        _Point(
          'Instalments are due on the 1st of every month. Paying on the 1st to the 3rd '
              'has no extra charge. From the 4th, a late fee of Rs. 10 applies, and it increases '
              'by Rs. 10 for every following month that an instalment is delayed.',
          lead: 'SIP due dates:',
        ),
        _Point(
          'Go to Profile and open My SIP, then enter your code to see instalments paid, '
              'instalments remaining, the amount paid, the amount pending and the gold or '
              'silver collected so far.',
          lead: 'Tracking your SIP:',
        ),
        _Point(
          'Open Profile and then Girvi Section to see the details of your pawned items.',
          lead: 'Girvi:',
        ),
        _Point(
          'Tap the bell on the Home screen to read messages and daily rate updates '
              'from the shop.',
          lead: 'Notifications:',
        ),

        _Heading('Information We Collect'),
        _Point('Your name, mobile number and email address.'),
        _Point(
          'Your PAN number, only if you choose to add it. It is required for a single '
              'purchase of Rs. 2,00,000 or more.',
        ),
        _Point(
          'Your Quick Buy and SIP payment records: amount, grams, rate, date, time and '
              'payment ID.',
        ),
        _Point(
          'For a SIP, the details you give at the shop: name, mobile number, the last 4 '
              'digits of your Aadhaar, your photo and your signature.',
        ),
        _Point('Girvi records created for you by the shop.'),

        _Heading('How We Use Your Information'),
        _Point('To create your account and show your balances and history.'),
        _Point('To process payments and keep a correct record of every instalment.'),
        _Point('To contact you about your SIP, girvi or purchases.'),
        _Point('To meet legal and tax requirements for gold and silver sales.'),

        _Heading('What We Do Not Store'),
        _Point(
          'Your card, UPI or bank details. Payments are handled entirely by Razorpay.',
        ),
        _Point(
          'Your full Aadhaar number inside the app database. Only the last 4 digits are '
              'kept. The full number appears only on the printed SIP form given to you.',
        ),
        _Point('Your full PAN number is never shown openly. It is displayed in a masked form.'),

        _Heading('Storage and Security'),
        _Point(
          'Your data is stored on Google Firebase. Access rules make sure you can see '
              'only your own profile and purchase history.',
        ),
        _Point(
          'Your SIP photo, signature and mobile number can be viewed only by the shop '
              'administrator.',
        ),
        _Point(
          'Anyone who knows your SIP code can open that SIP and make a payment. Please keep '
              'your code private. If you lose it, contact the shop immediately.',
        ),

        _Heading('Sharing of Information'),
        _Point('We do not sell your information.'),
        _Point(
          'It is shared only with Razorpay (to take payments), Google Firebase (to store data) '
              'and with authorities when the law requires it.',
        ),

        _Heading('Your Choices'),
        _Point('You can update your name, mobile number and PAN from Profile at any time.'),
        _Point(
          'You can delete your account any time from Profile > Delete my account. To '
              'correct other data, contact the shop. Records linked to an active SIP, a '
              'girvi loan, a payment or a legal requirement may have to be kept.',
        ),

        _Heading('Important Notes'),
        _Point('Rates shown are the shop\'s own rates and may change during the day.'),
        _Point(
          'Grams shown before you pay are estimates. The actual grams are calculated at the '
              'rate on the day each payment is made.',
        ),
        _Point('Investments carry no guarantee of profit.'),
        _Point('The terms printed on your signed SIP form apply to your SIP.'),

        _Heading('Contact Us'),
        _Para('Surpatne Jewellers'),
        _Para('Phone and WhatsApp: +91 $_kShopPhone1, +91 $_kShopPhone2'),
        SizedBox(height: 10),
      ],
    );
  }
}

// =====================================================================
// HELP & SUPPORT PAGE
// =====================================================================

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  Future<void> _open(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open')),
      );
    }
  }

  Widget _contactCard(BuildContext context, String title, String number) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.charcoal,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '+91 $number',
                  style: TextStyle(
                    color: AppColors.charcoal.withOpacity(0.6),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Call',
            icon: const Icon(Icons.call_outlined, color: AppColors.goldDark),
            onPressed: () => _open(context, Uri(scheme: 'tel', path: '+91$number')),
          ),
          IconButton(
            tooltip: 'WhatsApp',
            icon: const Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
            onPressed: () => _open(
              context,
              Uri.parse(
                'https://wa.me/91$number?text=${Uri.encodeComponent("Hello Surpatne Jewellers, I need some help.")}',
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _PageScaffold(
      title: 'Help & Support',
      children: [
        const _Para('Talk to the shop directly. We are happy to help.'),

        const _Heading('Contact the Shop'),
        _contactCard(context, 'Surpatne Jewellers', _kShopPhone1),
        _contactCard(context, 'Shop / Sales', _kShopPhone2),

        const _Heading('Common Questions'),
        const _Point(
          'The shop gives you a 6 digit code when you fill the SIP form. Please contact the '
              'shop with your name and mobile number. Keep the code safe, because the SIP terms '
              'say a lost code can lead to cancellation.',
          lead: 'I lost my SIP code. What should I do?',
        ),
        const _Point(
          'Instalments are due on the 1st of each month. Payment from the 1st to the 3rd has '
              'no extra charge. A late fee of Rs. 10 starts from the 4th, and increases by '
              'Rs. 10 for each following month.',
          lead: 'When is my SIP instalment due?',
        ),
        const _Point(
          'A SIP can be closed only by the shop. Please visit the shop in person.',
          lead: 'How do I stop my SIP?',
        ),
        const _Point(
          'Take a screenshot of the payment screen and call the shop with your payment ID. '
              'We will check and update your record.',
          lead: 'My payment was deducted but my balance did not change.',
        ),
        const _Point(
          'Open Profile and tap Personal Information to change your name, mobile number or PAN.',
          lead: 'How do I update my details?',
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}