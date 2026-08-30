import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../models/product.dart';
import '../../widgets/hubsom_image.dart';
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
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final seller = snap.data;
        if (seller == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Store not found')),
          );
        }
        final initial = seller.name.isNotEmpty
            ? seller.name.substring(0, 1).toUpperCase()
            : 'S';
        return Scaffold(
          appBar: AppBar(
            title: Text(seller.name),
            actions: [
              TextButton(
                onPressed: () =>
                    ref.read(catalogRepositoryProvider).followSeller(seller.id),
                child: const Text('Follow'),
              ),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: HubsomColors.forest,
                      child: seller.avatar.trim().isEmpty
                          ? Text(
                              initial,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                              ),
                            )
                          : ClipOval(
                              child: HubsomImage(
                                url: seller.avatar,
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                                placeholder: Container(
                                  width: 72,
                                  height: 72,
                                  color: HubsomColors.forest,
                                  alignment: Alignment.center,
                                  child: Text(
                                    initial,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            seller.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(seller.bio),
                          Text(
                            '${seller.city}, ${seller.region} · ★ ${seller.rating.toStringAsFixed(1)} · ${seller.followers} followers',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder(
                  future: ref
                      .read(catalogRepositoryProvider)
                      .listProducts(sellerId: seller.id),
                  builder: (context, pSnap) {
                    final products = pSnap.data ?? <Product>[];
                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.68,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
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
