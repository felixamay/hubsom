import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/providers/core_providers.dart';
import '../../core/services/maps_service.dart';
import '../../core/theme/hubsom_colors.dart';

/// Delivery tracking / Locate buyer pin — OpenStreetMap (no Google Maps).
class DeliveryMapPage extends ConsumerStatefulWidget {
  const DeliveryMapPage({super.key, required this.shipmentId});
  final String shipmentId;

  @override
  ConsumerState<DeliveryMapPage> createState() => _DeliveryMapPageState();
}

class _DeliveryMapPageState extends ConsumerState<DeliveryMapPage> {
  LatLng destination = MapsService.defaultCenter;
  List<LatLng> route = [];
  String status = 'loading';

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
      }
      final maps = ref.read(mapsServiceProvider);
      final from = MapsService.defaultCenter;
      route = await maps.routeOpenRouteService(from, destination);
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
            child: Center(child: Text(status, style: const TextStyle(fontWeight: FontWeight.w700))),
          ),
        ],
      ),
      body: FlutterMap(
        options: MapOptions(initialCenter: destination, initialZoom: 13),
        children: [
          TileLayer(
            urlTemplate: MapsService.osmTileUrl,
            userAgentPackageName: 'com.hubsom.app',
          ),
          if (route.isNotEmpty)
            PolylineLayer(polylines: [
              Polyline(points: route, color: HubsomColors.blue, strokeWidth: 4),
            ]),
          MarkerLayer(markers: [
            Marker(
              point: MapsService.defaultCenter,
              width: 40,
              height: 40,
              child: const Icon(Icons.store, color: HubsomColors.forest),
            ),
            Marker(
              point: destination,
              width: 40,
              height: 40,
              child: const Icon(Icons.location_pin, color: HubsomColors.live, size: 36),
            ),
          ]),
        ],
      ),
    );
  }
}
