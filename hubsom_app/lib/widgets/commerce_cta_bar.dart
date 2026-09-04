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
  });

  final String primaryLabel;
  final String secondaryLabel;
  final VoidCallback? onPrimary;
  final VoidCallback? onSecondary;
  final bool enabled;
  final bool dense;

  /// Dark glass treatment for video/timeline overlays.
  final bool overlay;

  @override
  Widget build(BuildContext context) {
    final h = dense ? 44.0 : 52.0;
    final radius = BorderRadius.circular(dense ? 14 : 16);

    final secondary = _CtaButton(
      label: secondaryLabel,
      height: h,
      radius: radius,
      onPressed: enabled ? onSecondary : null,
      variant: overlay ? _CtaVariant.glass : _CtaVariant.outline,
      icon: Icons.visibility_outlined,
    );
    final primary = _CtaButton(
      label: primaryLabel,
      height: h,
      radius: radius,
      onPressed: enabled ? onPrimary : null,
      variant: _CtaVariant.gold,
      icon: Icons.shopping_bag_outlined,
    );

    return Row(
      children: [
        Expanded(child: secondary),
        SizedBox(width: dense ? 10 : 12),
        Expanded(flex: dense ? 1 : 1, child: primary),
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
        borderRadius: BorderRadius.circular(18),
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
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              child: Row(
                children: [
                  _Thumb(imageUrl: imageUrl),
                  const SizedBox(width: 10),
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
                            fontSize: 13,
                            letterSpacing: 0.1,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          formatGhs(priceGhs),
                          style: const TextStyle(
                            color: HubsomColors.gold,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: CommerceCtaBar(
                dense: true,
                overlay: true,
                enabled: inStock,
                secondaryLabel: 'View product',
                primaryLabel: inStock ? 'Buy now' : 'Sold out',
                onSecondary: onView,
                onPrimary: inStock ? onBuy : null,
              ),
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
    this.onPressed,
  });

  final String label;
  final double height;
  final BorderRadius radius;
  final _CtaVariant variant;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;

    late final Decoration decoration;
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
                  colors: [Color(0xFFFFB347), HubsomColors.gold, Color(0xFFE67E00)],
                ),
          color: disabled ? const Color(0xFFD1D5DB) : null,
          boxShadow: disabled
              ? null
              : [
                  BoxShadow(
                    color: HubsomColors.gold.withValues(alpha: 0.45),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: height < 48 ? 16 : 18, color: foreground),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w800,
                    fontSize: height < 48 ? 12.5 : 14,
                    letterSpacing: 0.2,
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
  const _Thumb({required this.imageUrl});
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: (imageUrl ?? '').isNotEmpty
          ? HubsomImage(
              url: imageUrl!,
              width: 52,
              height: 52,
              fit: BoxFit.cover,
            )
          : const ColoredBox(
              color: HubsomColors.forest,
              child: Icon(Icons.shopping_bag, color: Colors.white, size: 22),
            ),
    );
  }
}
