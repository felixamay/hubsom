import 'package:flutter/material.dart';

import '../core/theme/hubsom_colors.dart';
import '../core/utils/money.dart';
import '../models/product.dart';
import 'hubsom_image.dart';

/// Pinned live product for sale (not on auction). Tapping the product opens it.
class LiveSaleProductCard extends StatelessWidget {
  const LiveSaleProductCard({
    super.key,
    required this.product,
    required this.offeredQty,
    required this.isHost,
    required this.onOpenProduct,
    required this.onDismiss,
    this.onBuy,
  });

  final Product product;
  final int offeredQty;
  final bool isHost;
  final VoidCallback onOpenProduct;
  final VoidCallback onDismiss;
  final VoidCallback? onBuy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onOpenProduct,
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 52,
                        height: 52,
                        child: product.images.isNotEmpty
                            ? HubsomImage(
                                url: product.images.first,
                                width: 52,
                                height: 52,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                color: HubsomColors.mist,
                                child: const Icon(Icons.shopping_bag),
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            formatGhs(product.effectivePrice),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            '$offeredQty for sale · Huber shipping',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!isHost && onBuy != null)
              FilledButton(
                onPressed: offeredQty <= 0 ? null : onBuy,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE91E63),
                ),
                child: Text(offeredQty <= 0 ? 'Sold out' : 'Buy'),
              ),
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
