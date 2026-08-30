import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Official Hubsom mark. Tapping navigates home unless [linkToHome] is false.
class HubsomLogo extends StatelessWidget {
  const HubsomLogo({
    super.key,
    this.height = 36,
    this.showWordmark = false,
    this.linkToHome = true,
  });

  final double height;
  final bool showWordmark;
  final bool linkToHome;

  @override
  Widget build(BuildContext context) {
    final mark = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/brand/hubsom-logo.png',
          height: height,
          width: height,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => Icon(
            Icons.storefront,
            size: height,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        if (showWordmark) ...[
          const SizedBox(width: 10),
          Text(
            'Hubsom',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ],
      ],
    );

    if (!linkToHome) return mark;

    return Tooltip(
      message: 'Home',
      child: InkWell(
        onTap: () {
          final router = GoRouter.maybeOf(context);
          if (router == null) return;
          router.go('/');
        },
        borderRadius: BorderRadius.circular(8),
        child: mark,
      ),
    );
  }
}
