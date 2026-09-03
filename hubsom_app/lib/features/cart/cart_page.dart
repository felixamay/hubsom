import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/core_providers.dart';
import '../../core/utils/money.dart';

class CartPage extends ConsumerWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final subtotal = cart.fold<double>(0, (s, e) => s + e.lineTotal);
    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: cart.isEmpty
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Your cart is empty'),
                const SizedBox(height: 12),
                FilledButton(onPressed: () => context.go('/marketplace'), child: const Text('Shop marketplace')),
              ]),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: cart.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (_, i) {
                final item = cart[i];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${formatGhs(item.priceGhs)} · ${item.source}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      onPressed: () => ref.read(cartProvider.notifier).setQuantity(item.productId, item.quantity - 1),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text('${item.quantity}'),
                    IconButton(
                      onPressed: () => ref.read(cartProvider.notifier).setQuantity(item.productId, item.quantity + 1),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ]),
                );
              },
            ),
      bottomNavigationBar: cart.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    const Text('Subtotal', style: TextStyle(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text(formatGhs(subtotal), style: const TextStyle(fontWeight: FontWeight.w900)),
                  ]),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => context.push('/checkout'),
                      child: const Text('Checkout'),
                    ),
                  ),
                ]),
              ),
            ),
    );
  }
}
