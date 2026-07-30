import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/hubsom_colors.dart';
import '../core/utils/money.dart';
import '../models/product.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, this.onSave});

  final Product product;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final image = product.images.isNotEmpty ? product.images.first : null;
    return InkWell(
      onTap: () => context.push('/products/${product.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (image != null && image.startsWith('http'))
                    CachedNetworkImage(
                      imageUrl: image,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: HubsomColors.mist),
                      errorWidget: (_, __, ___) => _placeholder(),
                    )
                  else
                    _placeholder(),
                  if (product.flashSale != null)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        color: HubsomColors.live,
                        child: Text(
                          '-${product.flashSale!.discountPct}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  if (onSave != null)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: IconButton(
                        onPressed: onSave,
                        icon: const Icon(Icons.favorite_border, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            formatGhs(product.effectivePrice),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: HubsomColors.forest,
                  fontWeight: FontWeight.w800,
                ),
          ),
          if (product.rating > 0)
            Row(
              children: [
                const Icon(Icons.star, size: 14, color: HubsomColors.gold),
                const SizedBox(width: 2),
                Text(
                  '${product.rating.toStringAsFixed(1)} (${product.reviewCount})',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
        color: HubsomColors.mist,
        alignment: Alignment.center,
        child: const Icon(Icons.image_outlined, color: HubsomColors.forest),
      );
}
