import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';

class SellerStorePage extends ConsumerStatefulWidget {
  const SellerStorePage({super.key});
  @override
  ConsumerState<SellerStorePage> createState() => _SellerStorePageState();
}

class _SellerStorePageState extends ConsumerState<SellerStorePage> {
  final _name = TextEditingController();
  final _bio = TextEditingController();
  final _city = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final store = await ref.read(sellerRepositoryProvider).myStore();
    if (store != null && mounted) {
      _name.text = store.name;
      _bio.text = store.bio;
      _city.text = store.city;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _name.dispose(); _bio.dispose(); _city.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Store settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Store name')),
          const SizedBox(height: 8),
          TextField(controller: _city, decoration: const InputDecoration(labelText: 'City')),
          const SizedBox(height: 8),
          TextField(controller: _bio, decoration: const InputDecoration(labelText: 'Bio'), maxLines: 4),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : () async {
              setState(() => _busy = true);
              await ref.read(sellerRepositoryProvider).updateStore({
                'name': _name.text.trim(),
                'city': _city.text.trim(),
                'bio': _bio.text.trim(),
              });
              if (mounted) setState(() => _busy = false);
            },
            child: Text(_busy ? 'Saving…' : 'Save store'),
          ),
        ],
      ),
    );
  }
}
