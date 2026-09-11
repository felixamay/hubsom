import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../../models/product.dart';
import '../../models/promotion.dart';
import '../../widgets/product_card.dart';
import '../../widgets/promo_banner.dart';
import '../../widgets/responsive_scaffold.dart';

class MarketplacePage extends ConsumerStatefulWidget {
  const MarketplacePage({super.key});

  @override
  ConsumerState<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends ConsumerState<MarketplacePage> {
  final _q = TextEditingController();
  String? _category;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = (
      category: _category,
      q: _q.text.trim().isEmpty ? null : _q.text.trim(),
    );
    final productsAsync = ref.watch(productsProvider(args));
    final promosAsync = ref.watch(promotionsProvider('marketplace'));
    final cross = ResponsiveScaffold.isWide(context)
        ? 5
        : ResponsiveScaffold.isTablet(context)
            ? 3
            : 2;

    final products = productsAsync.when(
      data: (list) => list.whereType<Product>().toList(),
      loading: () => const <Product>[],
      error: (_, __) => const <Product>[],
    );

    final promos = promosAsync.when(
      data: (list) => list.whereType<Promotion>().toList(),
      loading: () => const <Promotion>[],
      error: (_, __) => const <Promotion>[],
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Marketplace')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _q,
                  decoration: const InputDecoration(
                    hintText: 'Search products…',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                PromoBanner(promotions: promos),
                const SizedBox(height: 12),
                Expanded(
                  child: products.isEmpty
                      ? const Center(child: Text('No products found'))
                      : GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cross,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.68,
                          ),
                          itemCount: products.length,
                          itemBuilder: (_, i) => ProductCard(product: products[i]),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
