import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Recreates the "SJ" gold monogram with a small sparkle accent,
/// as seen in the brand logo.
class SJLogo extends StatelessWidget {
  final double size;
  const SJLogo({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.5,
      height: size * 1.2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: size * 0.18,
            child: ShaderMask(
              shaderCallback: (bounds) =>
                  AppColors.goldGradient.createShader(bounds),
              child: Text(
                'S',
                style: GoogleFonts.playfairDisplay(
                  fontSize: size,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1,
                ),
              ),
            ),
          ),
          Positioned(
            left: size * 0.62,
            top: 0,
            child: ShaderMask(
              shaderCallback: (bounds) =>
                  AppColors.goldGradient.createShader(bounds),
              child: Text(
                'J',
                style: GoogleFonts.playfairDisplay(
                  fontSize: size,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1,
                ),
              ),
            ),
          ),
          Positioned(
            right: size * 0.02,
            top: -size * 0.18,
            child: ShaderMask(
              shaderCallback: (bounds) =>
                  AppColors.goldGradient.createShader(bounds),
              child: Icon(Icons.auto_awesome,
                  size: size * 0.28, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
