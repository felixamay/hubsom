import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/hubsom_colors.dart';

/// Official Hubsom mark: live-shop bag emblem (+ optional wordmark).
/// Tapping navigates home unless [linkToHome] is false.
class HubsomLogo extends StatelessWidget {
  const HubsomLogo({
    super.key,
    this.height = 36,
    this.showWordmark = false,
    this.linkToHome = true,
    this.wordmarkColor,
  });

  final double height;
  final bool showWordmark;
  final bool linkToHome;
  final Color? wordmarkColor;

  void _goHome(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    router.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final mark = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: height,
          width: height,
          child: CustomPaint(
            size: Size(height, height),
            painter: const HubsomMarkPainter(),
          ),
        ),
        if (showWordmark) ...[
          SizedBox(width: height * 0.22),
          Text(
            'Hubsom',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  height: 1,
                  fontSize: height * 0.58,
                  color: wordmarkColor ?? primary,
                ),
          ),
        ],
      ],
    );

    if (!linkToHome) return mark;

    return Semantics(
      button: true,
      label: 'Hubsom home',
      child: Tooltip(
        message: 'Home',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _goHome(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: mark,
            ),
          ),
        ),
      ),
    );
  }
}

/// Vector live-commerce emblem: navy tile, shopping bag, play badge, gold arc.
class HubsomMarkPainter extends CustomPainter {
  const HubsomMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) return;
    final origin = Offset((size.width - s) / 2, (size.height - s) / 2);
    canvas.save();
    canvas.translate(origin.dx, origin.dy);

    final tile = RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.04, s * 0.04, s * 0.92, s * 0.92),
      Radius.circular(s * 0.22),
    );
    canvas.drawRRect(tile, Paint()..color = HubsomColors.forest);

    final white = Paint()..color = Colors.white;
    final bagTop = s * 0.40;
    final bagBottom = s * 0.74;
    final bag = Path()
      ..moveTo(s * 0.30, bagTop)
      ..lineTo(s * 0.70, bagTop)
      ..lineTo(s * 0.74, bagBottom)
      ..lineTo(s * 0.26, bagBottom)
      ..close();
    canvas.drawPath(bag, white);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(s * 0.288, s * 0.378, s * 0.712, s * 0.44),
        Radius.circular(s * 0.03),
      ),
      white,
    );

    final handlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.065
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromLTRB(s * 0.325, s * 0.215, s * 0.465, s * 0.44),
      math.pi * 1.08,
      math.pi * 0.92,
      false,
      handlePaint,
    );
    canvas.drawArc(
      Rect.fromLTRB(s * 0.535, s * 0.215, s * 0.675, s * 0.44),
      math.pi * 1.08,
      math.pi * 0.92,
      false,
      handlePaint,
    );

    final cx = s * 0.5;
    final cy = s * 0.56;
    final br = s * 0.105;
    canvas.drawCircle(Offset(cx, cy), br, Paint()..color = HubsomColors.cyan);
    final play = Path()
      ..moveTo(cx - br * 0.28, cy - br * 0.48)
      ..lineTo(cx - br * 0.28, cy + br * 0.48)
      ..lineTo(cx + br * 0.55, cy)
      ..close();
    canvas.drawPath(play, white);

    final swoosh = Paint()
      ..color = HubsomColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.035
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromLTRB(s * 0.24, s * 0.70, s * 0.76, s * 0.88),
      math.pi * 1.15,
      math.pi * 0.70,
      false,
      swoosh,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant HubsomMarkPainter oldDelegate) => false;
}
