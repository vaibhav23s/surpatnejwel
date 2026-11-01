import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CollectionCard extends StatelessWidget {
  final String title;
  final String price;
  final String image;
  final VoidCallback? onExplore;

  const CollectionCard({
    super.key,
    required this.title,
    required this.price,
    required this.image,
    this.onExplore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.gold.withOpacity(0.25),
        ),
        color: const Color.fromRGBO(255, 233, 204, 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              SizedBox(
                height: 140,
                width: double.infinity,
                child: Image.asset(
                  image,
                  fit: BoxFit.cover,
                ),
              ),

              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const RibbonCelebrateButton(),
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5A4632),
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  price,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gold,
                  ),
                ),

                const SizedBox(height: 8),

                InkWell(
                  onTap: onExplore,
                  child: Row(
                    children: [
                      const Text(
                        'Explore',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B6258),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward,
                        color: AppColors.gold,
                        size: 13,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
// =====================================================
// HEART + CONFETTI BUTTON
// =====================================================

class RibbonCelebrateButton extends StatefulWidget {
  const RibbonCelebrateButton({super.key});

  @override
  State<RibbonCelebrateButton> createState() =>
      _RibbonCelebrateButtonState();
}

class _RibbonCelebrateButtonState
    extends State<RibbonCelebrateButton> {
  bool isClicked = false;

  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();

    _confettiController = ConfettiController(
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ConfettiWidget(
          confettiController: _confettiController,

          blastDirection: -pi / 2,

          blastDirectionality:
          BlastDirectionality.explosive,

          maxBlastForce: 20,
          minBlastForce: 5,

          emissionFrequency: 0.05,

          numberOfParticles: 20,

          gravity: 0.3,

          shouldLoop: false,

          colors: const [
            Colors.red,
            Colors.blue,
            Colors.green,
            Colors.yellow,
            Colors.pink,
            Colors.purple,
            Colors.orange,
          ],
        ),

        GestureDetector(
          onTap: () {
            setState(() {
              isClicked = !isClicked;
            });

            if (isClicked) {
              _confettiController.stop();
              _confettiController.play();
            }
          },
          child: Icon(
            isClicked
                ? Icons.favorite
                : Icons.favorite_border,
            color: isClicked
                ? Colors.red
                : Colors.black,
            size: 25,
          ),
        ),
      ],
    );
  }
}