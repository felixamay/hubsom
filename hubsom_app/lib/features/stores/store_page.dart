import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../../models/product.dart';
import '../../widgets/product_card.dart';

class StorePage extends ConsumerWidget {
  const StorePage({super.key, required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: ref.read(catalogRepositoryProvider).getSeller(slug),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
        }
        final seller = snap.data;
        if (seller == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('Store not found')));
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(seller.name),
            actions: [
              TextButton(
                onPressed: () => ref.read(catalogRepositoryProvider).followSeller(seller.id),
                child: const Text('Follow'),
              ),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(seller.bio),
                  Text('${seller.city}, ${seller.region} · ★ ${seller.rating.toStringAsFixed(1)} · ${seller.followers} followers'),
                ]),
              ),
              Expanded(
                child: FutureBuilder(
                  future: ref.read(catalogRepositoryProvider).listProducts(sellerId: seller.id),
                  builder: (context, pSnap) {
                    final products = pSnap.data ?? <Product>[];
                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, childAspectRatio: 0.68, mainAxisSpacing: 12, crossAxisSpacing: 12,
                      ),
                      itemCount: products.length,
                      itemBuilder: (_, i) => ProductCard(product: products[i]),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
