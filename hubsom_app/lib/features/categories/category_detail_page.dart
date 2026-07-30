import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/categories.dart';
import '../../core/providers/core_providers.dart';
import '../../models/product.dart';
import '../../models/promotion.dart';
import '../../widgets/product_card.dart';
import '../../widgets/promo_banner.dart';
import '../../widgets/responsive_scaffold.dart';

class CategoryDetailPage extends ConsumerWidget {
  const CategoryDetailPage({super.key, required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = hubsomCategories.where((c) => c.slug == slug).firstOrNull;
    final productsAsync = ref.watch(productsProvider((category: slug, q: null)));
    final promosAsync = ref.watch(promotionsProvider('category'));
    final cross = ResponsiveScaffold.isWide(context) ? 5 : 2;

    return Scaffold(
      appBar: AppBar(title: Text(meta?.name ?? slug)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (meta != null) Text(meta.description),
            const SizedBox(height: 12),
            promosAsync.when(
              data: (list) {
                final filtered = list.cast<Promotion>().where((p) =>
                    p.categorySlugs.isEmpty || p.categorySlugs.contains(slug)).toList();
                return PromoBanner(promotions: filtered);
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: productsAsync.when(
                data: (products) => GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cross,
                    childAspectRatio: 0.68,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: products.length,
                  itemBuilder: (_, i) => ProductCard(product: products[i] as Product),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('$e'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
