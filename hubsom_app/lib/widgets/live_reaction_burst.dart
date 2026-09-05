import 'dart:math';

import 'package:flutter/material.dart';

import '../models/live_reaction_kind.dart';

/// Full-screen live reaction animation (fire, party, boom, 100).
class LiveReactionBurst extends StatelessWidget {
  const LiveReactionBurst({
    super.key,
    required this.kind,
    required this.progress,
    this.combo = 1,
  });

  final LiveReactionKind kind;
  final double progress;
  final int combo;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final fade =
        progress < 0.72 ? 1.0 : (1 - (progress - 0.72) / 0.28).clamp(0.0, 1.0);
    final pop = Curves.elasticOut.transform((progress / 0.34).clamp(0.0, 1.0));
    final pulse = 1 + 0.08 * sin(progress * pi * 8);
    final isFire = kind.fx == ReactionFx.fire;
    final emojiSize = isFire ? 112.0 : 88.0;

    Offset emojiAt;
    if (kind.id == 'rocket') {
      emojiAt = Offset(
        size.width * (-0.1 + progress * 1.2),
        size.height * (0.78 - progress * 0.6),
      );
    } else {
      emojiAt = Offset(size.width / 2, size.height * 0.4);
    }

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
                      kind.color.withValues(alpha: (isFire ? 0.38 : 0.22) * fade),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              for (var i = 0; i < (isFire ? 16 : 10); i++)
                _spark(size, i, isFire ? 16 : 10),
              Positioned(
                left: emojiAt.dx - emojiSize / 2,
                top: emojiAt.dy - emojiSize / 2,
                child: Transform.rotate(
                  angle: kind.id == 'rocket'
                      ? -0.55
                      : sin(progress * pi * 4) * 0.14,
                  child: Transform.scale(
                    scale: pop * pulse,
                    child: Text(
                      kind.emoji,
                      style: TextStyle(
                        fontSize: emojiSize,
                        shadows: [
                          Shadow(blurRadius: 22, color: kind.color),
                          const Shadow(blurRadius: 10, color: Colors.black54),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                top: size.height * 0.58,
                child: Column(
                  children: [
                    Text(
                      kind.name.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        letterSpacing: 3,
                        shadows: [
                          Shadow(blurRadius: 12, color: kind.color),
                        ],
                      ),
                    ),
                    if (combo > 1) ...[
                      const SizedBox(height: 4),
                      Text(
                        'x$combo',
                        style: TextStyle(
                          color: kind.color,
                          fontWeight: FontWeight.w900,
                          fontSize: 36,
                          shadows: const [
                            Shadow(blurRadius: 10, color: Colors.black87),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _spark(Size size, int i, int total) {
    final seed = (i + 1) * 1.9;
    final rise = (progress * (0.65 + (i % 5) * 0.07)).clamp(0.0, 1.0);
    final x = size.width * (0.12 + (i / max(total - 1, 1)) * 0.76) +
        sin(progress * pi * 3 + seed) * 20;
    final y = size.height * (0.86 - rise * 0.7);
    return Positioned(
      left: x,
      top: y,
      child: Opacity(
        opacity: (1 - rise).clamp(0.0, 1.0),
        child: Transform.scale(
          scale: 0.45 + (1 - rise) * 0.7,
          child: Text(
            kind.emoji,
            style: TextStyle(fontSize: 16.0 + (i % 3) * 5),
          ),
        ),
      ),
    );
  }
}
