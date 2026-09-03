import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../../widgets/product_card.dart';

class SavedPage extends ConsumerWidget {
  const SavedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final ids = user?.savedProductIds ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('Saved')),
      body: FutureBuilder(
        future: ref.read(catalogRepositoryProvider).listProducts(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!.where((p) => ids.contains(p.id)).toList();
          if (list.isEmpty) return const Center(child: Text('No saved products'));
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, childAspectRatio: 0.68, mainAxisSpacing: 12, crossAxisSpacing: 12,
            ),
            itemCount: list.length,
            itemBuilder: (_, i) => ProductCard(product: list[i]),
          );
        },
      ),
    );
  }
}
