import 'package:flutter/material.dart';

class HubsomLogo extends StatelessWidget {
  const HubsomLogo({super.key, this.height = 36, this.showWordmark = false});

  final double height;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/brand/hubsom-logo.png',
          height: height,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            Icons.storefront,
            size: height,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        if (showWordmark) ...[
          const SizedBox(width: 8),
          Text(
            'Hubsom',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
          ),
        ],
      ],
    );
  }
}
