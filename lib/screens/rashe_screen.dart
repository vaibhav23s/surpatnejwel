import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'rashi.dart';

/// राशि → रत्न. 12 rashi ki list; kisi par dabao to ratna, fayde aur pehnne ka tarika.
class RashiScreen extends StatelessWidget {
  const RashiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.goldDark),
        title: Text('राशि और रत्न',
            style: AppText.heading.copyWith(color: AppColors.black, fontSize: 20)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 30),
        itemCount: kRashiList.length,
        itemBuilder: (context, i) {
          final r = kRashiList[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => RashiDetailScreen(info: r)),
                ),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.gold.withOpacity(0.13),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(r.symbol,
                            style: const TextStyle(fontSize: 24, color: AppColors.goldDark)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.name,
                                style: const TextStyle(
                                    color: AppColors.charcoal,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text('${r.gemstoneNameHi}  •  स्वामी: ${r.rulingPlanet}',
                                style: TextStyle(
                                    color: AppColors.charcoal.withOpacity(0.55), fontSize: 11.5)),
                          ],
                        ),
                      ),
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: r.gemstoneColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black26),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward_ios_rounded,
                          size: 13, color: AppColors.goldDark.withOpacity(0.55)),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class RashiDetailScreen extends StatelessWidget {
  final RashiInfo info;
  const RashiDetailScreen({super.key, required this.info});

  Widget _card(String title, String body) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.gold.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: AppColors.goldDark, fontSize: 13, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(body,
                style: TextStyle(
                    color: AppColors.charcoal.withOpacity(0.85), fontSize: 13.5, height: 1.6)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.goldDark),
        title: Text('${info.name} ${info.symbol}',
            style: AppText.heading.copyWith(color: AppColors.black, fontSize: 20)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: info.gemstoneColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(info.gemstoneNameHi,
                            style: const TextStyle(
                                color: AppColors.black, fontSize: 18, fontWeight: FontWeight.w800)),
                        Text(info.gemstoneNameEn,
                            style: const TextStyle(color: AppColors.black, fontSize: 12.5)),
                        const SizedBox(height: 4),
                        Text('नाम के अक्षर: ${info.letters}',
                            style: const TextStyle(color: AppColors.black, fontSize: 11.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _card('राशि और ग्रह', info.about),
            _card('रत्न के फायदे', info.benefits),
            _card('पहनने का तरीका', info.howToWear),
            Text(
              'यह जानकारी सामान्य मान्यताओं पर आधारित है। रत्न पहनने से पहले किसी योग्य ज्योतिषी से सलाह ज़रूर लें।',
              style: TextStyle(color: AppColors.charcoal.withOpacity(0.5), fontSize: 11, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
