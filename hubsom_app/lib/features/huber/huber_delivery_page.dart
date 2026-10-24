import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/providers/core_providers.dart';
import '../../core/services/maps_service.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../core/utils/money.dart';
import '../../models/huber.dart';

class HuberDeliveryPage extends ConsumerStatefulWidget {
  const HuberDeliveryPage({super.key, required this.deliveryId});

  final String deliveryId;

  @override
  ConsumerState<HuberDeliveryPage> createState() => _HuberDeliveryPageState();
}

class _HuberDeliveryPageState extends ConsumerState<HuberDeliveryPage> {
  HuberDelivery? _delivery;
  String _podType = 'pin';
  final _pod = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _delivery = ref.read(huberRepositoryProvider).deliveryById(widget.deliveryId);
  }

  @override
  void dispose() {
    _pod.dispose();
    super.dispose();
  }

  Future<void> _advance() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final next =
          await ref.read(huberRepositoryProvider).advanceDelivery(widget.deliveryId);
      if (!mounted) return;
      setState(() => _delivery = next);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _complete() async {
    if ((_podType == 'pin' || _podType == 'qr') && _pod.text.trim().length < 4) {
      setState(() => _error = 'Enter at least 4 digits for proof of delivery');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final next =
          await ref.read(huberRepositoryProvider).completeDelivery(widget.deliveryId);
      if (!mounted) return;
      setState(() => _delivery = next);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery completed')),
      );
      context.go('/huber/earnings');
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _delivery;
    if (d == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Active delivery')),
        body: const Center(child: Text('Delivery not found')),
      );
    }

    final pickup = LatLng(
      d.pickupLatitude ?? MapsService.defaultCenter.latitude,
      d.pickupLongitude ?? MapsService.defaultCenter.longitude,
    );
    final dropoff = LatLng(
      d.dropoffLatitude ?? pickup.latitude + 0.02,
      d.dropoffLongitude ?? pickup.longitude + 0.02,
    );
    final showPod = d.status == 'arrived_dropoff';

    return Scaffold(
      appBar: AppBar(title: const Text('Active delivery')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            d.stepLabel,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: HubsomColors.huberNavy,
                ),
          ),
          const SizedBox(height: 8),
          Text(d.sellerName, style: Theme.of(context).textTheme.titleMedium),
          Text('Pickup: ${d.pickupAddress}'),
          Text('Customer: ${d.customerName}'),
          Text('Drop-off: ${d.dropoffAddress}'),
          Text(formatGhs(d.feeGhs), style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: FlutterMap(
                options: MapOptions(initialCenter: pickup, initialZoom: 12),
                children: [
                  TileLayer(
                    urlTemplate: MapsService.osmTileUrl,
                    userAgentPackageName: 'com.hubsom.app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: pickup,
                        width: 36,
                        height: 36,
                        child: const Icon(Icons.store, color: HubsomColors.forest),
                      ),
                      Marker(
                        point: dropoff,
                        width: 36,
                        height: 36,
                        child: const Icon(Icons.location_pin, color: HubsomColors.live, size: 32),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (d.status != 'delivered' && !showPod)
            FilledButton(
              onPressed: _busy ? null : _advance,
              child: Text(_busy ? 'Updating…' : _cta(d.status)),
            ),
          if (showPod) ...[
            Text('Proof of delivery', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final t in const ['pin', 'qr', 'signature', 'photo'])
                  ChoiceChip(
                    label: Text(t.toUpperCase()),
                    selected: _podType == t,
                    onSelected: (_) => setState(() => _podType = t),
                  ),
              ],
            ),
            if (_podType == 'pin' || _podType == 'qr') ...[
              const SizedBox(height: 8),
              TextField(
                controller: _pod,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Enter ${_podType.toUpperCase()}'),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _complete,
              child: const Text('Complete delivery'),
            ),
          ],
          if (d.status == 'delivered')
            const Text('This delivery is complete.'),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
    );
  }

  String _cta(String status) => switch (status) {
        'accepted' => 'Start navigation to pickup',
        'en_route_pickup' => 'Arrived at pickup',
        'arrived_pickup' => 'Confirm pickup',
        'picked_up' => 'Navigate to customer',
        'en_route_dropoff' => 'Arrived at customer',
        _ => 'Continue',
      };
}
