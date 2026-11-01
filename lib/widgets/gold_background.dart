import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Paints the soft flowing gold ribbon lines + faint sparkle dust seen
/// on the splash / login backgrounds.
class GoldRibbonPainter extends CustomPainter {
  final bool topLeft;
  final bool bottomRight;
  GoldRibbonPainter({this.topLeft = true, this.bottomRight = true});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..shader = AppColors.goldGradient.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      );

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = AppColors.gold.withOpacity(0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    if (topLeft) {
      final p1 = Path()
        ..moveTo(-20, size.height * 0.05)
        ..quadraticBezierTo(
          size.width * 0.25,
          size.height * 0.02,
          size.width * 0.4,
          size.height * 0.22,
        )
        ..quadraticBezierTo(
          size.width * 0.5,
          size.height * 0.32,
          size.width * 0.15,
          size.height * 0.42,
        );
      canvas.drawPath(p1, glow);
      canvas.drawPath(p1, paint);

      final p2 = Path()
        ..moveTo(-30, size.height * 0.14)
        ..quadraticBezierTo(
          size.width * 0.18,
          size.height * 0.1,
          size.width * 0.3,
          size.height * 0.26,
        );
      canvas.drawPath(p2, paint..strokeWidth = 1.2);
    }

    if (bottomRight) {
      final p3 = Path()
        ..moveTo(size.width * 0.7, size.height)
        ..quadraticBezierTo(
          size.width * 0.98,
          size.height * 0.82,
          size.width * 0.78,
          size.height * 0.66,
        )
        ..quadraticBezierTo(
          size.width * 0.62,
          size.height * 0.54,
          size.width * 1.05,
          size.height * 0.4,
        );
      canvas.drawPath(p3, glow);
      canvas.drawPath(p3, paint..strokeWidth = 2);
    }

    // sparkle dust
    final dustPaint = Paint()..color = AppColors.gold.withOpacity(0.5);
    final dustSpots = topLeft
        ? [
            Offset(size.width * 0.08, size.height * 0.08),
            Offset(size.width * 0.15, size.height * 0.15),
            Offset(size.width * 0.05, size.height * 0.2),
          ]
        : [
            Offset(size.width * 0.9, size.height * 0.75),
            Offset(size.width * 0.85, size.height * 0.85),
          ];
    for (final spot in dustSpots) {
      canvas.drawCircle(spot, 1.4, dustPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Wraps a screen with the standard black vignette + gold ribbons background.
class GoldDecoratedBackground extends StatelessWidget {
  final Widget child;
  const GoldDecoratedBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.blackVignette),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: GoldRibbonPainter()),
          ),
          child,
        ],
      ),
    );
  }
}
