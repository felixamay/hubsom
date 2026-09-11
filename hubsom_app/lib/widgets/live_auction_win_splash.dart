import 'dart:math';

import 'package:flutter/material.dart';

import '../core/theme/hubsom_colors.dart';
import '../core/utils/money.dart';

/// Full-screen celebration when a live auction lot sells.
class LiveAuctionWinSplash extends StatelessWidget {
  const LiveAuctionWinSplash({
    super.key,
    required this.winnerName,
    required this.amountGhs,
    required this.productName,
    required this.progress,
    this.isYou = false,
  });

  static const duration = Duration(milliseconds: 4200);

  final String winnerName;
  final double amountGhs;
  final String productName;
  final double progress;
  final bool isYou;

  static String headline({
    required String winnerName,
    required bool isYou,
  }) =>
      isYou ? 'You won!' : '$winnerName won!';

  static String chatLine({
    required String winnerName,
    required String productName,
    required double amountGhs,
  }) =>
      '🏆 $winnerName won $productName — ${amountGhs.toStringAsFixed(0)} GHS';

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final fade =
        progress < 0.78 ? 1.0 : (1 - (progress - 0.78) / 0.22).clamp(0.0, 1.0);
    final pop = Curves.elasticOut.transform((progress / 0.36).clamp(0.0, 1.0));
    final pulse = 1 + 0.05 * sin(progress * pi * 7);
    final title = headline(winnerName: winnerName, isYou: isYou);

    return IgnorePointer(
      child: SizedBox.expand(
        child: Opacity(
          opacity: fade,
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      HubsomColors.gold.withValues(alpha: 0.42 * fade),
                      Colors.black.withValues(alpha: 0.62 * fade),
                    ],
                  ),
                ),
              ),
              for (var i = 0; i < 18; i++) _confetti(size, i),
              Center(
                child: Transform.scale(
                  scale: pop * pulse,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: const [
                          BoxShadow(blurRadius: 28, color: Colors.black54),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🏆', style: TextStyle(fontSize: 56)),
                            const SizedBox(height: 6),
                            const Text(
                              'SOLD',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 4,
                                fontSize: 18,
                                color: HubsomColors.gold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 28,
                                color: HubsomColors.ink,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              productName,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: Color(0xFF333333),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              formatGhs(amountGhs),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 32,
                                color: HubsomColors.forest,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isYou
                                  ? 'The host will confirm your order'
                                  : 'Winning bid',
                              style: const TextStyle(
                                color: Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _confetti(Size size, int i) {
    final seed = (i + 1) * 2.13;
    final rise = (progress * (0.7 + (i % 4) * 0.08)).clamp(0.0, 1.0);
    final x = size.width * (0.06 + (i / 17) * 0.88) +
        sin(progress * pi * 3 + seed) * 22;
    final y = size.height * (0.92 - rise * 0.95);
    final marks = ['🎉', '✨', '🏆', '💰', '🎊'];
    return Positioned(
      left: x,
      top: y,
      child: Opacity(
        opacity: (1 - rise * 0.35).clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: progress * pi * (i.isEven ? 2 : -2),
          child: Text(
            marks[i % marks.length],
            style: TextStyle(fontSize: 16.0 + (i % 4) * 4),
          ),
        ),
      ),
    );
  }
}
