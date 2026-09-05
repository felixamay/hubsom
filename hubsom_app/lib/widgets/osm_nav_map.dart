import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/services/maps_service.dart';
import '../core/theme/hubsom_colors.dart';

/// OpenStreetMap + flutter_map navigation canvas for Huber riders.
class OsmNavMap extends StatefulWidget {
  const OsmNavMap({
    super.key,
    required this.pickup,
    required this.dropoff,
    this.rider,
    this.route = const [],
    this.navigateToPickup = true,
    this.height = 280,
    this.pickupLabel = 'Seller store',
    this.dropoffLabel = 'Buyer',
  });

  final LatLng pickup;
  final LatLng dropoff;
  final LatLng? rider;
  final List<LatLng> route;
  final bool navigateToPickup;
  final double height;
  final String pickupLabel;
  final String dropoffLabel;

  @override
  State<OsmNavMap> createState() => _OsmNavMapState();
}

class _OsmNavMapState extends State<OsmNavMap> {
  final _controller = MapController();

  LatLng get _target =>
      widget.navigateToPickup ? widget.pickup : widget.dropoff;

  LatLng get _from => widget.rider ??
      (widget.navigateToPickup ? widget.pickup : widget.dropoff);

  @override
  void didUpdateWidget(covariant OsmNavMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.route != widget.route ||
        oldWidget.rider != widget.rider ||
        oldWidget.navigateToPickup != widget.navigateToPickup) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
    }
  }

  void _fit() {
    final pts = <LatLng>{
      if (widget.rider != null) widget.rider!,
      widget.pickup,
      widget.dropoff,
      ...widget.route,
    }.toList();
    if (pts.length < 2) return;
    try {
      _controller.fitCamera(
        CameraFit.coordinates(
          coordinates: pts,
          padding: const EdgeInsets.all(36),
          maxZoom: 16,
        ),
      );
    } catch (_) {}
  }

  Future<void> _openDirections() async {
    final uri = MapsService.osmDirectionsUri(_from, _target);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter: _target,
                initialZoom: 13,
                onMapReady: _fit,
              ),
              children: [
                TileLayer(
                  urlTemplate: MapsService.osmTileUrl,
                  userAgentPackageName: 'com.hubsom.app',
                ),
                if (widget.route.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: widget.route,
                        color: HubsomColors.blue,
                        strokeWidth: 4.5,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: widget.pickup,
                      width: 40,
                      height: 40,
                      child: Tooltip(
                        message: widget.pickupLabel,
                        child: const Icon(
                          Icons.store,
                          color: HubsomColors.forest,
                          size: 32,
                        ),
                      ),
                    ),
                    Marker(
                      point: widget.dropoff,
                      width: 40,
                      height: 40,
                      child: Tooltip(
                        message: widget.dropoffLabel,
                        child: const Icon(
                          Icons.location_pin,
                          color: HubsomColors.live,
                          size: 36,
                        ),
                      ),
                    ),
                    if (widget.rider != null)
                      Marker(
                        point: widget.rider!,
                        width: 40,
                        height: 40,
                        child: const Tooltip(
                          message: 'You',
                          child: Icon(
                            Icons.navigation,
                            color: HubsomColors.blue,
                            size: 30,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: Colors.white.withValues(alpha: 0.85),
                child: const Text(
                  '© OpenStreetMap',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: FilledButton.icon(
                onPressed: _openDirections,
                icon: const Icon(Icons.directions, size: 18),
                label: Text(
                  widget.navigateToPickup
                      ? 'Navigate to store'
                      : 'Navigate to buyer',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
