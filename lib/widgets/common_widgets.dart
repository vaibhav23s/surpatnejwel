import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Primary CTA button with the signature gold gradient.
class GoldButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final double height;
  const GoldButton({
    super.key,
    required this.label,
    this.onTap,
    this.height = 54,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: AppColors.goldGradient,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.black,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

/// Outlined secondary button (used for Google / Apple continue).
class OutlineButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback? onTap;
  const OutlineButton({
    super.key,
    required this.label,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.gold.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: AppText.body.copyWith(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gold-outlined text field matching the login screen inputs.
class GoldTextField extends StatelessWidget {
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  const GoldTextField({
    super.key,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.suffix,
    this.controller,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: AppText.body,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppText.bodyMuted,
        prefixIcon: Icon(icon, color: AppColors.gold, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.transparent,
        contentPadding:
        const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: AppColors.gold.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.4),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: AppColors.gold.withOpacity(0.5)),
        ),
      ),
    );
  }
}

/// Small gold circular icon-button (used for back / menu / settings / bell).
class GoldCircleIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool hasDot;
  const GoldCircleIcon({
    super.key,
    required this.icon,
    this.onTap,
    this.hasDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold.withOpacity(0.6)),
            ),
            child: Icon(icon, color: AppColors.gold, size: 20),
          ),
          if (hasDot)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: AppColors.gold,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Section title with a thin gold divider line, e.g. "OUR COLLECTION".
class GoldSectionTitle extends StatelessWidget {
  final String title;
  const GoldSectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    Widget line() => Expanded(
      child: Container(
        height: 1,
        color: AppColors.gold.withOpacity(0.4),
      ),
    );
    return Row(
      children: [
        line(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            title,
            style: AppText.goldLabel.copyWith(
              fontSize: 13,
              letterSpacing: 1.5,
            ),
          ),
        ),
        line(),
      ],
    );
  }
}