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
                      'No delivery pin yet',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Allow location to save the GPS coordinate riders should use.',
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
                final area = a.displayArea;
                return ListTile(
                  leading: const Icon(
                    Icons.my_location,
                    color: HubsomColors.forest,
                  ),
                  title: Text(a.displayLine),
                  subtitle: Text(
                    [
                      a.label,
                      if (area.isNotEmpty) 'Near $area',
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
    GeoLocation? pin;
    var busy = false;
    String? error;

    final saved = await showModalBottomSheet<GeoLocation>(
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
                pin = await ref.read(locationServiceProvider).current();
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
                    'Delivery GPS pin',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 12),
                  GpsPinCard(
                    title: 'Your address',
                    subtitle:
                        'This saved pin is your address — not a default Accra location.',
                    pin: pin,
                    busy: busy,
                    error: error,
                    onUseLocation: allow,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      if (pin == null) {
                        setLocal(
                          () => error = 'Allow location to save this address.',
                        );
                        return;
                      }
                      Navigator.pop(ctx, pin);
                    },
                    child: const Text('Save GPS address'),
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
    final next = await UserAddressStore.saveAllowedGps(
      user: user,
      pin: saved,
    );
    ref.read(authStateProvider.notifier).applyLocalUser(next);
  }
}
