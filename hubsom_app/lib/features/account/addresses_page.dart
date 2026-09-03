import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';

class AddressesPage extends ConsumerWidget {
  const AddressesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final addresses = user?.addresses ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('Addresses')),
      body: addresses.isEmpty
          ? const Center(child: Text('No saved addresses'))
          : ListView.builder(
              itemCount: addresses.length,
              itemBuilder: (_, i) {
                final a = addresses[i];
                return ListTile(
                  title: Text('${a.label} · ${a.line1}'),
                  subtitle: Text('${a.city}, ${a.region}${a.phone != null ? ' · ${a.phone}' : ''}'),
                  trailing: a.isDefault == true ? const Chip(label: Text('Default')) : null,
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await ref.read(apiClientProvider).post('/api/account/addresses', data: {
            'label': 'Home',
            'line1': 'Accra',
            'city': 'Accra',
            'region': 'Greater Accra',
          });
          await ref.read(authStateProvider.notifier).refresh();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
