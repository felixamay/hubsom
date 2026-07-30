import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
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
          Expanded(
            flex: 5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _ProductImage(url: image, name: product.name),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 28, 10, 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.72),
                          ],
                        ),
                      ),
                      child: Text(
                        formatGhs(product.effectivePrice),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
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
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            formatGhs(product.effectivePrice),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: HubsomColors.forest,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.url, required this.name});

  final String? url;
  final String name;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) return _fallback();

    // cached_network_image can be flaky on some web builds; Image.network is reliable.
    if (kIsWeb) {
      return Image.network(
        url!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            color: HubsomColors.mist,
            alignment: Alignment.center,
            child: const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
      );
    }

    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(color: HubsomColors.mist),
      errorWidget: (_, __, ___) => _fallback(),
    );
  }

  Widget _fallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [HubsomColors.mint, HubsomColors.forest],
        ),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      child: Text(
        name,
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    );
  }
}
