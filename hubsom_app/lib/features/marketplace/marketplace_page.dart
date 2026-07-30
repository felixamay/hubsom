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
    final args = (category: _category, q: _q.text.trim().isEmpty ? null : _q.text.trim());
    final productsAsync = ref.watch(productsProvider(args));
    final promosAsync = ref.watch(promotionsProvider('marketplace'));
    final cross = ResponsiveScaffold.isWide(context) ? 5 : ResponsiveScaffold.isTablet(context) ? 3 : 2;

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
                  decoration: InputDecoration(
                    hintText: 'Search products…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.tune),
                      onPressed: () async {
                        // simple category filter via dialog
                      },
                    ),
                  ),
                  onSubmitted: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                promosAsync.when(
                  data: (list) => PromoBanner(promotions: list.cast<Promotion>()),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: productsAsync.when(
                    data: (products) {
                      final list = products.cast<Product>();
                      if (list.isEmpty) {
                        return const Center(child: Text('No products found'));
                      }
                      return GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cross,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.68,
                        ),
                        itemCount: list.length,
                        itemBuilder: (_, i) => ProductCard(
                          product: list[i],
                          onSave: () => ref.read(catalogRepositoryProvider).toggleSave(list[i].id),
                        ),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('$e')),
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
