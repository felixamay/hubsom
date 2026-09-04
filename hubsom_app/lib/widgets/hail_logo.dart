import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/hubsom_colors.dart';

/// Stylish Hail wordmark + mark for the rider app header.
class HailLogo extends StatelessWidget {
  const HailLogo({
    super.key,
    this.height = 32,
    this.showWordmark = true,
  });

  final double height;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final wordStyle = TextStyle(
      fontSize: height * 0.72,
      fontWeight: FontWeight.w900,
      letterSpacing: -1.2,
      height: 1,
      fontStyle: FontStyle.italic,
      color: HubsomColors.huberNavy,
    );

    return Semantics(
      label: 'Hail',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: height,
            width: height,
            child: CustomPaint(
              size: Size(height, height),
              painter: const HailMarkPainter(),
            ),
          ),
          if (showWordmark) ...[
            SizedBox(width: height * 0.16),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hail', style: wordStyle),
                SizedBox(height: height * 0.04),
                SizedBox(
                  width: height * 1.7,
                  height: height * 0.16,
                  child: const CustomPaint(painter: _HailSwooshPainter()),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Pin + motion chevron mark: “hail a rider”.
class HailMarkPainter extends CustomPainter {
  const HailMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) return;
    final cx = s * 0.5;
    final navy = Paint()..color = HubsomColors.huberNavy;
    final cyan = Paint()..color = HubsomColors.cyan;
    final white = Paint()..color = Colors.white;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.04, s * 0.04, s * 0.92, s * 0.92),
        Radius.circular(s * 0.28),
      ),
      navy,
    );

    final pin = Path()
      ..moveTo(cx, s * 0.78)
      ..quadraticBezierTo(s * 0.18, s * 0.48, s * 0.22, s * 0.34)
      ..arcToPoint(
        Offset(s * 0.78, s * 0.34),
        radius: Radius.circular(s * 0.28),
        clockwise: true,
      )
      ..quadraticBezierTo(s * 0.82, s * 0.48, cx, s * 0.78)
      ..close();
    canvas.drawPath(pin, white);

    canvas.drawCircle(Offset(cx, s * 0.36), s * 0.12, cyan);

    final chevron = Paint()
      ..color = HubsomColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.055
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (var i = 0; i < 2; i++) {
      final dx = s * (0.58 + i * 0.1);
      final path = Path()
        ..moveTo(dx, s * 0.62)
        ..lineTo(dx + s * 0.08, s * 0.68)
        ..lineTo(dx, s * 0.74);
      canvas.drawPath(path, chevron);
    }
  }

  @override
  bool shouldRepaint(covariant HailMarkPainter oldDelegate) => false;
}

class _HailSwooshPainter extends CustomPainter {
  const _HailSwooshPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = HubsomColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.0, size.height * 0.45)
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * 0.02, size.height * 0.55)
      ..quadraticBezierTo(
        size.width * 0.48,
        size.height * 1.2,
        size.width * 0.98,
        size.height * 0.15,
      );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HailSwooshPainter oldDelegate) => false;
}
