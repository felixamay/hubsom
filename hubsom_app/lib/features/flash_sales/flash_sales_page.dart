import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../models/product.dart';
import '../../widgets/product_card.dart';
import '../../widgets/responsive_scaffold.dart';

class FlashSalesPage extends ConsumerWidget {
  const FlashSalesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider((category: null, q: null)));
    final signedIn = ref.watch(authStateProvider).valueOrNull != null;
    final cross = ResponsiveScaffold.isWide(context)
        ? 4
        : ResponsiveScaffold.isTablet(context)
            ? 3
            : 2;

    return Scaffold(
      appBar: AppBar(title: const Text('Flash sales')),
      body: productsAsync.when(
        data: (products) {
          final list = products
              .cast<Product>()
              .where((p) => p.hasActiveFlashSale)
              .toList();
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.bolt_outlined,
                      size: 48,
                      color: HubsomColors.live,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No flash sales active',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sellers can enable a flash sale when creating or editing a product.',
                      textAlign: TextAlign.center,
                    ),
                    if (signedIn) ...[
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => context.push('/seller/products/new'),
                        child: const Text('List a flash sale'),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(productsProvider((category: null, q: null)));
              await ref.read(productsProvider((category: null, q: null)).future);
            },
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cross,
                childAspectRatio: 0.68,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemCount: list.length,
              itemBuilder: (_, i) => ProductCard(product: list[i]),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}
