import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../services/rate_store.dart';

class RateHistoryScreen extends StatelessWidget {
  const RateHistoryScreen({super.key});

  String _formatCurrency(num value) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(value);
  }

  DateTime _getDate(dynamic value) {
    if (value is DateTime) return value;

    // Firestore Timestamp
    try {
      return value.toDate();
    } catch (_) {
      return DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    final rateStore = RateStore();

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Rate History',
          style: AppText.heading,
        ),
        iconTheme: const IconThemeData(
          color: AppColors.charcoal,
        ),
      ),

      body: StreamBuilder<DailyRates>(
        stream: rateStore.watchRates(),
        builder: (context, todaySnapshot) {
          if (todaySnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.gold,
              ),
            );
          }

          final today = todaySnapshot.data;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---------------------------------------------------------
                // TODAY'S LIVE RATE
                // ---------------------------------------------------------

                Text(
                  'LIVE MARKET RATE',
                  style: AppText.goldLabel,
                ),

                const SizedBox(height: 6),

                const Text(
                  "Today's Rate",
                  style: TextStyle(
                    color: AppColors.charcoal,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 16),

                if (today != null)
                  Row(
                    children: [
                      Expanded(
                        child: _LiveRateCard(
                          title: '24K GOLD',
                          subtitle: '99.9% Purity • 1g',
                          value: _formatCurrency(today.gold10gInr),
                          icon: Icons.diamond_outlined,
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: _LiveRateCard(
                          title: 'SILVER',
                          subtitle: '99.9% Purity • 10g',
                          value: _formatCurrency(today.silverKgInr),
                          icon: Icons.circle_outlined,
                        ),
                      ),
                    ],
                  )
                else
                  const _InfoBox(
                    text: 'Today\'s rate is not available.',
                  ),

                const SizedBox(height: 32),

                // ---------------------------------------------------------
                // HISTORY
                // ---------------------------------------------------------

                Text(
                  'RATE HISTORY',
                  style: AppText.goldLabel,
                ),

                const SizedBox(height: 6),

                const Text(
                  'Previous Market Rates',
                  style: TextStyle(
                    color: AppColors.charcoal,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 18),

                StreamBuilder<List<RateHistoryItem>>(
                  stream: rateStore.watchRateHistory(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.gold,
                          ),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return _InfoBox(
                        text: 'Unable to load rate history.',
                      );
                    }

                    final history = snapshot.data ?? [];

                    if (history.isEmpty) {
                      return const _EmptyHistory();
                    }

                    return Column(
                      children: List.generate(
                        history.length,
                            (index) {
                          final item = history[index];

                          return _HistoryCard(
                            item: item,
                            isLatest: index == 0,
                            formatCurrency: _formatCurrency,
                            getDate: _getDate,
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ================================================================
// LIVE RATE CARD
// ================================================================

class _LiveRateCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String value;
  final IconData icon;

  const _LiveRateCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.gold.withOpacity(0.30),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: AppColors.goldDark,
                  size: 20,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          Text(
            title,
            style: const TextStyle(
              color: AppColors.goldDark,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            subtitle,
            style: TextStyle(
              color: AppColors.charcoal.withOpacity(0.55),
              fontSize: 10,
            ),
          ),

          const SizedBox(height: 12),

          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.charcoal,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// HISTORY CARD
// ================================================================

class _HistoryCard extends StatelessWidget {
  final RateHistoryItem item;
  final bool isLatest;
  final String Function(num) formatCurrency;
  final DateTime Function(dynamic) getDate;

  const _HistoryCard({
    required this.item,
    required this.isLatest,
    required this.formatCurrency,
    required this.getDate,
  });

  @override
  Widget build(BuildContext context) {
    final date = getDate(item.date);

    final dateText = DateFormat(
      'dd MMM yyyy',
    ).format(date);

    final weekday = DateFormat(
      'EEEE',
    ).format(date);

    final time = DateFormat(
      'hh:mm a',
    ).format(date);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.80),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isLatest
              ? AppColors.gold.withOpacity(0.55)
              : AppColors.gold.withOpacity(0.20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------------------------------------------------------
          // DATE ROW
          // ---------------------------------------------------------

          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.calendar_month_outlined,
                  color: AppColors.goldDark,
                  size: 22,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateText,
                      style: const TextStyle(
                        color: AppColors.charcoal,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$weekday • $time',
                      style: TextStyle(
                        color: AppColors.charcoal.withOpacity(0.52),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              if (isLatest)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppColors.goldGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'LATEST',
                    style: TextStyle(
                      color: AppColors.black,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 18),

          // ---------------------------------------------------------
          // GOLD + SILVER
          // ---------------------------------------------------------

          Row(
            children: [
              Expanded(
                child: _RateValue(
                  label: '24K GOLD',
                  subtitle: '1g',
                  value: formatCurrency(item.gold10gInr),
                  icon: Icons.diamond_outlined,
                ),
              ),

              Container(
                width: 1,
                height: 58,
                color: AppColors.gold.withOpacity(0.18),
              ),

              Expanded(
                child: _RateValue(
                  label: 'SILVER',
                  subtitle: '10g',
                  value: formatCurrency(item.silverKgInr),
                  icon: Icons.circle_outlined,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ---------------------------------------------------------
          // UPDATED INFO
          // ---------------------------------------------------------

          Row(
            children: [
              Icon(
                Icons.access_time_rounded,
                size: 14,
                color: AppColors.charcoal.withOpacity(0.45),
              ),
              const SizedBox(width: 5),
              Text(
                'Updated $time',
                style: TextStyle(
                  color: AppColors.charcoal.withOpacity(0.45),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ================================================================
// RATE VALUE
// ================================================================

class _RateValue extends StatelessWidget {
  final String label;
  final String subtitle;
  final String value;
  final IconData icon;

  const _RateValue({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 15,
                color: AppColors.goldDark,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.goldDark,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          Text(
            value,
            style: const TextStyle(
              color: AppColors.charcoal,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 2),

          Text(
            subtitle,
            style: TextStyle(
              color: AppColors.charcoal.withOpacity(0.45),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// EMPTY HISTORY
// ================================================================

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 35,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.gold.withOpacity(0.20),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.history_rounded,
            size: 42,
            color: AppColors.gold.withOpacity(0.55),
          ),

          const SizedBox(height: 12),

          const Text(
            'No Rate History',
            style: TextStyle(
              color: AppColors.charcoal,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            'Previous market rates will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.charcoal.withOpacity(0.50),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// INFO BOX
// ================================================================

class _InfoBox extends StatelessWidget {
  final String text;

  const _InfoBox({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.70),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.gold.withOpacity(0.20),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.charcoal.withOpacity(0.60),
          fontSize: 13,
        ),
      ),
    );
  }
}