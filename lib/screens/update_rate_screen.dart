import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/rate_store.dart';
import 'market_rate_screen.dart';

class UpdateRateScreen extends StatefulWidget {
  const UpdateRateScreen({super.key});

  @override
  State<UpdateRateScreen> createState() => _UpdateRateScreenState();
}

class _UpdateRateScreenState extends State<UpdateRateScreen> {
  final RateStore _rateStore = RateStore();

  final TextEditingController _goldController =
  TextEditingController();

  final TextEditingController _silverController =
  TextEditingController();

  bool _loading = true;
  bool _saving = false;
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rates = await _rateStore.getRates();

    _goldController.text =
        rates.gold10gInr.toStringAsFixed(0);

    _silverController.text =
        rates.silverKgInr.toStringAsFixed(0);

    if (!mounted) return;

    setState(() {
      _lastUpdated = rates.updatedAt;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final gold =
    double.tryParse(_goldController.text.trim());

    final silver =
    double.tryParse(_silverController.text.trim());

    if (gold == null ||
        silver == null ||
        gold <= 0 ||
        silver <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Dono fields me sahi number daalo',
          ),
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      // saveRates khud history entry bhi likhta hai
      await _rateStore.saveRates(
        gold10gInr: gold,
        silverKgInr: silver,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Rate successfully updated',
          ),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Save error: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _goldController.dispose();
    _silverController.dispose();
    super.dispose();
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');

    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}, $h:$m';
  }

  InputDecoration _fieldDecoration() {
    return InputDecoration(
      prefixText: '₹ ',
      prefixStyle: AppText.body.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      filled: true,
      fillColor: AppColors.charcoal,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: AppColors.gold.withValues(alpha: 0.4),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: AppColors.gold.withValues(alpha: 0.4),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: AppColors.gold,
          width: 1.4,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,

      appBar: AppBar(
        backgroundColor: AppColors.black,
        elevation: 0,
        iconTheme: const IconThemeData(
          color: AppColors.gold,
        ),
        title: Text(
          'Update Today\'s Rate',
          style: AppText.heading.copyWith(
            fontSize: 18,
          ),
        ),
      ),

      body: _loading
          ? const Center(
        child: CircularProgressIndicator(
          color: AppColors.gold,
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              'Jo bhi rate aaj dukan me/board pe hai, wahi yaha type kar do. Ye pure app me har jagah dikhega.',
              style: AppText.bodyMuted.copyWith(
                fontSize: 12.5,
              ),
            ),

            if (_lastUpdated != null) ...[
              const SizedBox(height: 8),

              Text(
                'Last update: ${_formatTime(_lastUpdated!)}',
                style: AppText.goldLabel.copyWith(
                  fontSize: 11.5,
                ),
              ),
            ],

            const SizedBox(height: 24),

            Text(
              '24K Gold — ₹ per 1 gram',
              style: AppText.body.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 8),

            TextField(
              controller: _goldController,
              keyboardType:
              const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: AppText.body.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              decoration: _fieldDecoration(),
            ),

            const SizedBox(height: 22),

            Text(
              'Silver — ₹ per 10 gram',
              style: AppText.body.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 8),

            TextField(
              controller: _silverController,
              keyboardType:
              const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: AppText.body.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              decoration: _fieldDecoration(),
            ),

            const SizedBox(height: 32),

            GoldButton(
              label: _saving
                  ? 'Saving...'
                  : 'Save Rate',
              onTap: _saving ? null : _save,
            ),

            const SizedBox(height: 20),

            Center(
              child: TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                      const RateHistoryScreen(),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.history,
                  color: AppColors.gold,
                ),
                label: const Text(
                  'View Rate History',
                  style: TextStyle(
                    color: AppColors.gold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}