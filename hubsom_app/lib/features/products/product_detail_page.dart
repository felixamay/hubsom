import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../core/utils/money.dart';
import '../../models/cart.dart';
import '../../models/product.dart';
import '../../models/review.dart';

class ProductDetailPage extends ConsumerWidget {
  const ProductDetailPage({super.key, required this.productId});
  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<Product?>(
      future: ref.read(catalogRepositoryProvider).getProduct(productId),
      builder: (context, snap) {
        if (!snap.hasData && !snap.hasError) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final product = snap.data;
        if (product == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('Product not found')));
        }
        final image = product.images.isNotEmpty ? product.images.first : null;
        return Scaffold(
          appBar: AppBar(
            title: Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(
                icon: const Icon(Icons.favorite_border),
                onPressed: () async {
                  await ref.read(catalogRepositoryProvider).toggleSave(product.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Saved to wishlist')),
                    );
                  }
                },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AspectRatio(
                aspectRatio: 1.1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: image != null && image.startsWith('http')
                      ? CachedNetworkImage(imageUrl: image, fit: BoxFit.cover)
                      : Container(color: HubsomColors.mist, child: const Icon(Icons.image, size: 64)),
                ),
              ),
              const SizedBox(height: 16),
              Text(product.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(formatGhs(product.effectivePrice),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: HubsomColors.forest, fontWeight: FontWeight.w800)),
              if (product.compareAtGhs != null)
                Text(formatGhs(product.compareAtGhs!),
                    style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey)),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.star, color: HubsomColors.gold, size: 18),
                Text(' ${product.rating.toStringAsFixed(1)} · ${product.reviewCount} reviews'),
                const Spacer(),
                Text('Stock: ${product.stock}'),
              ]),
              const SizedBox(height: 16),
              Text(product.description),
              const SizedBox(height: 16),
              Wrap(spacing: 8, children: [
                for (final t in product.tags)
                  Chip(label: Text(t), visualDensity: VisualDensity.compact),
              ]),
              const SizedBox(height: 24),
              Text('Reviews', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              FutureBuilder<List<ProductReview>>(
                future: ref.read(catalogRepositoryProvider).listReviews(product.id),
                builder: (context, r) {
                  final reviews = r.data ?? [];
                  if (reviews.isEmpty) return const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('No reviews yet'));
                  return Column(
                    children: reviews.take(5).map((rev) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${rev.userName} · ${rev.rating}/5'),
                      subtitle: Text(rev.comment),
                    )).toList(),
                  );
                },
              ),
              const SizedBox(height: 100),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await ref.read(cartProvider.notifier).add(CartItem(
                        productId: product.id,
                        quantity: 1,
                        source: 'buy-now',
                        name: product.name,
                        priceGhs: product.effectivePrice,
                        image: image,
                        category: product.category,
                      ));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to cart')));
                      }
                    },
                    child: const Text('Add to cart'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      await ref.read(cartProvider.notifier).add(CartItem(
                        productId: product.id,
                        quantity: 1,
                        source: 'buy-now',
                        name: product.name,
                        priceGhs: product.effectivePrice,
                        image: image,
                        category: product.category,
                      ));
                      if (context.mounted) context.push('/checkout');
                    },
                    child: const Text('Buy now'),
                  ),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}
