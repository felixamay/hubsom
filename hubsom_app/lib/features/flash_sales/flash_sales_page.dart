import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../../models/product.dart';
import '../../widgets/product_card.dart';

class FlashSalesPage extends ConsumerWidget {
  const FlashSalesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider((category: null, q: null)));
    return Scaffold(
      appBar: AppBar(title: const Text('Flash sales')),
      body: productsAsync.when(
        data: (products) {
          final list = products.cast<Product>().where((p) => p.flashSale != null).toList();
          if (list.isEmpty) return const Center(child: Text('No flash sales active'));
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, childAspectRatio: 0.68, mainAxisSpacing: 12, crossAxisSpacing: 12,
            ),
            itemCount: list.length,
            itemBuilder: (_, i) => ProductCard(product: list[i]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}
