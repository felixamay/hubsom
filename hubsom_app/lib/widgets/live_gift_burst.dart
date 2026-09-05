import 'dart:math';

import 'package:flutter/material.dart';

import '../core/theme/hubsom_colors.dart';
import '../models/live_gift.dart';

/// Full-screen gift send animation for a live room.
class LiveGiftBurst extends StatelessWidget {
  const LiveGiftBurst({
    super.key,
    required this.gift,
    required this.senderName,
    required this.progress,
  });

  final LiveGift gift;
  final String senderName;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final fade = progress < 0.72 ? 1.0 : (1 - (progress - 0.72) / 0.28).clamp(0.0, 1.0);
    final popT = Curves.elasticOut.transform((progress / 0.38).clamp(0.0, 1.0));
    final bannerT = Curves.easeOutCubic.transform((progress / 0.22).clamp(0.0, 1.0));
    final pulse = 1 + 0.06 * sin(progress * pi * 6);
    final emojiSize = switch (gift.fxTier) {
      GiftFxTier.mega => 118.0,
      GiftFxTier.large => 96.0,
      GiftFxTier.medium => 78.0,
      GiftFxTier.small => 64.0,
    };

    Offset emojiAt;
    if (gift.id == 'rocket') {
      emojiAt = Offset(
        size.width * (-0.15 + progress * 1.25),
        size.height * (0.78 - progress * 0.62),
      );
    } else {
      emojiAt = Offset(size.width / 2, size.height * 0.42);
    }

    final particleCount = switch (gift.fxTier) {
      GiftFxTier.mega => 14,
      GiftFxTier.large => 10,
      GiftFxTier.medium => 7,
      GiftFxTier.small => 4,
    };

    return IgnorePointer(
      child: SizedBox.expand(
        child: Opacity(
          opacity: fade,
          child: Stack(
            fit: StackFit.expand,
            children: [
            if (gift.fxTier.index >= GiftFxTier.large.index)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        HubsomColors.gold.withValues(alpha: 0.22 * fade),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 16 + (1 - bannerT) * -220,
              top: size.height * 0.22,
              right: 86,
              child: _GiftBanner(
                gift: gift,
                senderName: senderName,
              ),
            ),
            for (var i = 0; i < particleCount; i++)
              _particle(size, i, particleCount, emojiSize * 0.42),
            Positioned(
              left: emojiAt.dx - emojiSize / 2,
              top: emojiAt.dy - emojiSize / 2,
              child: Transform.rotate(
                angle: gift.id == 'rocket' ? -0.6 : sin(progress * pi * 3) * 0.12,
                child: Transform.scale(
                  scale: popT * pulse,
                  child: Text(
                    gift.emoji,
                    style: TextStyle(
                      fontSize: emojiSize,
                      shadows: const [
                        Shadow(blurRadius: 18, color: Colors.black54),
                      ],
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

  Widget _particle(Size size, int i, int total, double fontSize) {
    final seed = (i + 1) * 1.7;
    final rise = (progress * (0.55 + (i % 5) * 0.08)).clamp(0.0, 1.0);
    final x = size.width * (0.18 + (i / max(total - 1, 1)) * 0.64) +
        sin(progress * pi * 2 + seed) * 18;
    final y = size.height * (0.78 - rise * 0.55);
    final op = (1 - rise).clamp(0.0, 1.0);
    return Positioned(
      left: x,
      top: y,
      child: Opacity(
        opacity: op,
        child: Transform.scale(
          scale: 0.55 + (1 - rise) * 0.5,
          child: Text(gift.emoji, style: TextStyle(fontSize: fontSize)),
        ),
      ),
    );
  }
}

class _GiftBanner extends StatelessWidget {
  const _GiftBanner({required this.gift, required this.senderName});

  final LiveGift gift;
  final String senderName;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xE6F36F21), Color(0xE6F7941D)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(blurRadius: 16, color: Colors.black45),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 16, 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(gift.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    senderName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'sent ${gift.name} · ${gift.costPoints} pts',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
