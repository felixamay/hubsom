import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../../core/services/user_address_store.dart';
import '../../core/theme/hubsom_colors.dart';
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
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'No delivery address yet',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Allow location to save your delivery address.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => _addAddress(context, ref),
                      icon: const Icon(Icons.my_location),
                      label: const Text('Allow location'),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              itemCount: addresses.length,
              itemBuilder: (_, i) {
                final a = addresses[i];
                return ListTile(
                  leading: const Icon(
                    Icons.place_outlined,
                    color: HubsomColors.forest,
                  ),
                  title: Text(
                    a.displayLine.isEmpty ? a.label : a.displayLine,
                  ),
                  subtitle: Text(
                    [
                      a.label,
                      if (a.phone != null && a.phone!.isNotEmpty) a.phone!,
                    ].join(' · '),
                  ),
                  trailing: a.isDefault == true
                      ? const Chip(label: Text('Default'))
                      : null,
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addAddress(context, ref),
        icon: const Icon(Icons.my_location),
        label: const Text('Use GPS'),
      ),
    );
  }

  Future<void> _addAddress(BuildContext context, WidgetRef ref) async {
    UserAddress? draft;
    var busy = false;
    String? error;

    final saved = await showModalBottomSheet<UserAddress>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            Future<void> allow() async {
              setLocal(() {
                busy = true;
                error = null;
              });
              try {
                final pin = await ref.read(locationServiceProvider).current();
                draft = await UserAddressStore.fromAllowedGps(pin);
              } catch (e) {
                error = '$e';
              } finally {
                setLocal(() => busy = false);
              }
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                16 + MediaQuery.viewInsetsOf(ctx).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Delivery address',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 12),
                  GpsPinCard(
                    title: 'Your address',
                    pin: draft?.location,
                    address: draft?.displayLine,
                    busy: busy,
                    error: error,
                    onUseLocation: allow,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      if (draft == null) {
                        setLocal(
                          () => error = 'Allow location to save this address.',
                        );
                        return;
                      }
                      Navigator.pop(ctx, draft);
                    },
                    child: const Text('Save address'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (saved == null) return;
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    final pin = saved.location;
    if (pin == null) return;
    final next = await UserAddressStore.saveAllowedGps(
      user: user,
      pin: pin,
    );
    ref.read(authStateProvider.notifier).applyLocalUser(next);
  }
}
