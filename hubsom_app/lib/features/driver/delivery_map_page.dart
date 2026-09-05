import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/providers/core_providers.dart';
import '../../core/services/ghana_places.dart';
import '../../core/services/local_commerce_store.dart';
import '../../core/services/maps_service.dart';
import '../../widgets/osm_nav_map.dart';

/// Delivery tracking — OpenStreetMap route from seller store to buyer GPS.
class DeliveryMapPage extends ConsumerStatefulWidget {
  const DeliveryMapPage({super.key, required this.shipmentId});
  final String shipmentId;

  @override
  ConsumerState<DeliveryMapPage> createState() => _DeliveryMapPageState();
}

class _DeliveryMapPageState extends ConsumerState<DeliveryMapPage> {
  LatLng pickup = MapsService.defaultCenter;
  LatLng destination = MapsService.defaultCenter;
  List<LatLng> route = [];
  String status = 'loading';
  String pickupLabel = 'Seller store';
  String dropoffLabel = 'Buyer';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final shipments = await ref.read(orderRepositoryProvider).listShipments();
      final match = shipments.where((s) => s.id == widget.shipmentId).firstOrNull;
      final loc = match?.destination.location;
      if (loc != null) {
        destination = LatLng(loc.latitude, loc.longitude);
      } else if (match != null) {
        final pin = GhanaPlaces.resolve(
          address: match.destination.line1,
          city: match.destination.city,
          region: match.destination.region,
        );
        destination = pin;
      }
      dropoffLabel = match?.destination.line1 ?? 'Buyer';

      final seller = match == null
          ? null
          : LocalCommerceStore.getSeller(match.sellerId);
      if (seller != null) {
        pickup = GhanaPlaces.resolve(
          address: seller.address,
          city: seller.city,
          region: seller.region,
          latitude: seller.latitude,
          longitude: seller.longitude,
        );
        pickupLabel = seller.displayLocation.isNotEmpty
            ? seller.displayLocation
            : 'Seller store';
      }

      final maps = ref.read(mapsServiceProvider);
      route = await maps.routeBetween(pickup, destination);
      if (mounted) setState(() => status = match?.status ?? 'ready');
    } catch (_) {
      if (mounted) setState(() => status = 'map');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Track ${widget.shipmentId}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(status, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: OsmNavMap(
          pickup: pickup,
          dropoff: destination,
          route: route,
          navigateToPickup: false,
          height: MediaQuery.sizeOf(context).height - 140,
          pickupLabel: pickupLabel,
          dropoffLabel: dropoffLabel,
        ),
      ),
    );
  }
}
