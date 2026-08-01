import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/categories.dart';
import '../../core/providers/core_providers.dart';

class SellerProductNewPage extends ConsumerStatefulWidget {
  const SellerProductNewPage({super.key});
  @override
  ConsumerState<SellerProductNewPage> createState() => _SellerProductNewPageState();
}

class _SellerProductNewPageState extends ConsumerState<SellerProductNewPage> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _stock = TextEditingController(text: '10');
  String _category = hubsomCategories.first.slug;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose(); _description.dispose(); _price.dispose(); _stock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New product')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 8),
          TextField(controller: _description, decoration: const InputDecoration(labelText: 'Description'), maxLines: 4),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _category,
            items: [for (final c in hubsomCategories) DropdownMenuItem(value: c.slug, child: Text(c.name))],
            onChanged: (v) => setState(() => _category = v ?? _category),
            decoration: const InputDecoration(labelText: 'Category'),
          ),
          const SizedBox(height: 8),
          TextField(controller: _price, decoration: const InputDecoration(labelText: 'Price (GHS)'), keyboardType: TextInputType.number),
          const SizedBox(height: 8),
          TextField(controller: _stock, decoration: const InputDecoration(labelText: 'Stock'), keyboardType: TextInputType.number),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : () async {
              setState(() => _busy = true);
              try {
                final created = await ref.read(sellerRepositoryProvider).createProduct({
                  'name': _name.text.trim(),
                  'description': _description.text.trim(),
                  'category': _category,
                  'priceGhs': double.tryParse(_price.text) ?? 0,
                  'stock': int.tryParse(_stock.text) ?? 0,
                  'supports': [
                    'buy-now',
                    'store-listing',
                    'live-selling',
                    'live-auction',
                  ],
                });
                ref.invalidate(productsProvider((category: null, q: null)));
                await ref.read(authStateProvider.notifier).refresh();
                if (context.mounted) {
                  final id = created['id'] as String?;
                  if (id != null) {
                    context.go('/products/$id');
                  } else {
                    context.pop();
                  }
                }
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
            child: Text(_busy ? 'Creating…' : 'Publish product'),
          ),
        ],
      ),
    );
  }
}
