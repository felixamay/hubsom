import 'package:flutter/material.dart';

import '../core/theme/hubsom_colors.dart';
import '../core/utils/money.dart';
import 'hubsom_image.dart';

/// Premium dual CTA used on product detail and feed/timeline shop strips.
class CommerceCtaBar extends StatelessWidget {
  const CommerceCtaBar({
    super.key,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.onPrimary,
    required this.onSecondary,
    this.enabled = true,
    this.dense = false,
    this.overlay = false,
    this.compact = false,
  });

  final String primaryLabel;
  final String secondaryLabel;
  final VoidCallback? onPrimary;
  final VoidCallback? onSecondary;
  final bool enabled;
  final bool dense;

  /// Dark glass treatment for video/timeline overlays.
  final bool overlay;

  /// Extra-small sizing for tight feed/video shop strips.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final h = compact ? 32.0 : (dense ? 40.0 : 52.0);
    final radius = BorderRadius.circular(compact ? 10 : (dense ? 12 : 16));
    final gap = compact ? 6.0 : (dense ? 8.0 : 12.0);
    final iconSize = compact ? 13.0 : (dense ? 14.0 : 18.0);
    final fontSize = compact ? 10.5 : (dense ? 11.5 : 14.0);

    final secondary = _CtaButton(
      label: secondaryLabel,
      height: h,
      radius: radius,
      iconSize: iconSize,
      fontSize: fontSize,
      onPressed: enabled ? onSecondary : null,
      variant: overlay ? _CtaVariant.glass : _CtaVariant.outline,
      icon: Icons.visibility_outlined,
    );
    final primary = _CtaButton(
      label: primaryLabel,
      height: h,
      radius: radius,
      iconSize: iconSize,
      fontSize: fontSize,
      onPressed: enabled ? onPrimary : null,
      variant: _CtaVariant.gold,
      icon: Icons.shopping_bag_outlined,
    );

    return Row(
      children: [
        Expanded(flex: compact ? 8 : 10, child: secondary),
        SizedBox(width: gap),
        Expanded(flex: compact ? 10 : 9, child: primary),
      ],
    );
  }
}

/// Compact product row + View / Buy actions for dark feed overlays.
class FeedProductShopStrip extends StatelessWidget {
  const FeedProductShopStrip({
    super.key,
    required this.name,
    required this.priceGhs,
    required this.imageUrl,
    required this.onView,
    required this.onBuy,
    this.inStock = true,
  });

  final String name;
  final double priceGhs;
  final String? imageUrl;
  final VoidCallback onView;
  final VoidCallback onBuy;
  final bool inStock;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0.07),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _Thumb(imageUrl: imageUrl, size: 40),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: 0.1,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatGhs(priceGhs),
                        style: const TextStyle(
                          color: HubsomColors.gold,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: 0.15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            CommerceCtaBar(
              compact: true,
              overlay: true,
              enabled: inStock,
              secondaryLabel: 'View',
              primaryLabel: inStock ? 'Buy now' : 'Sold out',
              onSecondary: onView,
              onPrimary: inStock ? onBuy : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Elevated bottom purchase bar for product detail.
class ProductPurchaseBar extends StatelessWidget {
  const ProductPurchaseBar({
    super.key,
    required this.inStock,
    required this.onAddToCart,
    required this.onBuyNow,
  });

  final bool inStock;
  final VoidCallback onAddToCart;
  final VoidCallback onBuyNow;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: HubsomColors.ink.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
          border: Border(
            top: BorderSide(color: HubsomColors.mist.withValues(alpha: 0.9)),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: CommerceCtaBar(
              enabled: inStock,
              secondaryLabel: inStock ? 'Add to cart' : 'Sold out',
              primaryLabel: inStock ? 'Buy now' : 'Sold out',
              onSecondary: inStock ? onAddToCart : null,
              onPrimary: inStock ? onBuyNow : null,
            ),
          ),
        ),
      ),
    );
  }
}

enum _CtaVariant { gold, outline, glass }

class _CtaButton extends StatelessWidget {
  const _CtaButton({
    required this.label,
    required this.height,
    required this.radius,
    required this.variant,
    required this.icon,
    required this.iconSize,
    required this.fontSize,
    this.onPressed,
  });

  final String label;
  final double height;
  final BorderRadius radius;
  final _CtaVariant variant;
  final IconData icon;
  final double iconSize;
  final double fontSize;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;

    late final BoxDecoration decoration;
    late final Color foreground;

    switch (variant) {
      case _CtaVariant.gold:
        decoration = BoxDecoration(
          borderRadius: radius,
          gradient: disabled
              ? null
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFFB347),
                    HubsomColors.gold,
                    Color(0xFFE67E00),
                  ],
                ),
          color: disabled ? const Color(0xFFD1D5DB) : null,
          boxShadow: disabled
              ? null
              : [
                  BoxShadow(
                    color: HubsomColors.gold.withValues(alpha: 0.35),
                    blurRadius: height < 36 ? 6 : 14,
                    offset: Offset(0, height < 36 ? 2 : 5),
                  ),
                ],
        );
        foreground = disabled ? const Color(0xFF6B7280) : HubsomColors.ink;
      case _CtaVariant.outline:
        decoration = BoxDecoration(
          borderRadius: radius,
          color: disabled ? HubsomColors.mist : Colors.white,
          border: Border.all(
            color: disabled
                ? const Color(0xFFD1D5DB)
                : HubsomColors.forest.withValues(alpha: 0.55),
            width: 1.4,
          ),
        );
        foreground = disabled ? const Color(0xFF9CA3AF) : HubsomColors.forest;
      case _CtaVariant.glass:
        decoration = BoxDecoration(
          borderRadius: radius,
          color: Colors.white.withValues(alpha: disabled ? 0.08 : 0.14),
          border: Border.all(
            color: Colors.white.withValues(alpha: disabled ? 0.15 : 0.45),
            width: 1.2,
          ),
        );
        foreground = disabled ? Colors.white38 : Colors.white;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: radius,
        child: Ink(
          height: height,
          decoration: decoration,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: iconSize, color: foreground),
              const SizedBox(width: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      color: foreground,
                      fontWeight: FontWeight.w800,
                      fontSize: fontSize,
                      letterSpacing: 0.05,
                      height: 1.0,
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
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.imageUrl, this.size = 52});
  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: (imageUrl ?? '').isNotEmpty
          ? HubsomImage(
              url: imageUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
            )
          : ColoredBox(
              color: HubsomColors.forest,
              child: Icon(
                Icons.shopping_bag,
                color: Colors.white,
                size: size * 0.42,
              ),
            ),
    );
  }
}
