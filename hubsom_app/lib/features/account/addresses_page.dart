import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/core_providers.dart';
import '../../core/services/local_store.dart';
import '../../models/user.dart';
import '../../widgets/gps_pin_card.dart';

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
                final gps = a.location;
                return ListTile(
                  title: Text('${a.label} · ${a.line1}'),
                  subtitle: Text(
                    '${a.city}, ${a.region}'
                    '${a.phone != null ? ' · ${a.phone}' : ''}'
                    '${gps != null ? ' · GPS ${gps.latitude.toStringAsFixed(4)}, ${gps.longitude.toStringAsFixed(4)}' : ''}',
                  ),
                  trailing: a.isDefault == true
                      ? const Chip(label: Text('Default'))
                      : null,
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addAddress(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _addAddress(BuildContext context, WidgetRef ref) async {
    final line1 = TextEditingController();
    final city = TextEditingController(text: AppConstants.defaultCity);
    final region = TextEditingController(text: AppConstants.defaultRegion);
    GeoLocation? pin;
    var busy = false;
    String? error;

    final saved = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('Add delivery address'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: line1,
                      decoration: const InputDecoration(labelText: 'Street / area'),
                    ),
                    TextField(
                      controller: city,
                      decoration: const InputDecoration(labelText: 'City'),
                    ),
                    TextField(
                      controller: region,
                      decoration: const InputDecoration(labelText: 'Region'),
                    ),
                    const SizedBox(height: 12),
                    GpsPinCard(
                      title: 'Address GPS',
                      subtitle: 'Allow location so riders can navigate here.',
                      pin: pin,
                      busy: busy,
                      error: error,
                      onUseLocation: () async {
                        setLocal(() {
                          busy = true;
                          error = null;
                        });
                        try {
                          pin = await ref.read(locationServiceProvider).current();
                        } catch (e) {
                          error = '$e';
                        } finally {
                          setLocal(() => busy = false);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (pin == null) {
                      setLocal(() => error = 'Allow location before saving.');
                      return;
                    }
                    Navigator.pop(ctx, {
                      'label': 'Home',
                      'line1': line1.text.trim().isEmpty
                          ? 'Current location'
                          : line1.text.trim(),
                      'city': city.text.trim(),
                      'region': region.text.trim(),
                      'location': pin!.toJson(),
                    });
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
    line1.dispose();
    city.dispose();
    region.dispose();
    if (saved == null) return;
    final payload = {
      ...saved,
      'id': 'addr_${DateTime.now().millisecondsSinceEpoch}',
    };
    try {
      await ref.read(apiClientProvider).post('/api/account/addresses', data: payload);
    } catch (_) {}
    final user = ref.read(authStateProvider).valueOrNull;
    if (user != null) {
      final next = user.copyWith(
        addresses: [...user.addresses, UserAddress.fromJson(payload)],
      );
      await LocalStore.setUserJson(jsonEncode(next.toJson()));
      ref.read(authStateProvider.notifier).applyLocalUser(next);
    }
  }
}
