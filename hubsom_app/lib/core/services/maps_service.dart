import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import '../config/app_config.dart';

/// OpenStreetMap + OpenRouteService / OSRM / GraphHopper routing.
/// No Google Maps.
class MapsService {
  MapsService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  static const osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const defaultCenter = LatLng(5.6037, -0.1870); // Accra

  Future<List<LatLng>> routeOpenRouteService(LatLng from, LatLng to) async {
    if (AppConfig.openRouteServiceKey.isEmpty) {
      return routeOsrm(from, to);
    }
    final url =
        'https://api.openrouteservice.org/v2/directions/driving-car?api_key=${AppConfig.openRouteServiceKey}'
        '&start=${from.longitude},${from.latitude}&end=${to.longitude},${to.latitude}';
    final res = await _dio.get(url);
    final coords = res.data['features'][0]['geometry']['coordinates'] as List;
    return coords
        .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();
  }

  Future<List<LatLng>> routeOsrm(LatLng from, LatLng to) async {
    final url =
        'https://router.project-osrm.org/route/v1/driving/'
        '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson';
    final res = await _dio.get(url);
    final coords = res.data['routes'][0]['geometry']['coordinates'] as List;
    return coords
        .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();
  }

  Future<List<LatLng>> routeGraphHopper(LatLng from, LatLng to, {String? apiKey}) async {
    final key = apiKey ?? '';
    if (key.isEmpty) return routeOsrm(from, to);
    final url =
        'https://graphhopper.com/api/1/route?point=${from.latitude},${from.longitude}'
        '&point=${to.latitude},${to.longitude}&profile=car&points_encoded=false&key=$key';
    final res = await _dio.get(url);
    final coords = res.data['paths'][0]['points']['coordinates'] as List;
    return coords
        .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();
  }

  /// Road route with a straight-line fallback if every router is unreachable.
  Future<List<LatLng>> routeBetween(LatLng from, LatLng to) async {
    try {
      final pts = await routeOpenRouteService(from, to);
      if (pts.length >= 2) return pts;
    } catch (_) {}
    try {
      final pts = await routeOsrm(from, to);
      if (pts.length >= 2) return pts;
    } catch (_) {}
    return [from, to];
  }

  /// Seller store first, then the buyer after pickup.
  static LatLng navigationTarget({
    required String status,
    required LatLng pickup,
    required LatLng dropoff,
  }) {
    switch (status) {
      case 'picked_up':
      case 'en_route_dropoff':
      case 'arrived_dropoff':
      case 'delivered':
        return dropoff;
      default:
        return pickup;
    }
  }

  static bool navigatingToPickup(String status) {
    switch (status) {
      case 'picked_up':
      case 'en_route_dropoff':
      case 'arrived_dropoff':
      case 'delivered':
        return false;
      default:
        return true;
    }
  }

  static Uri osmDirectionsUri(LatLng from, LatLng to) {
    return Uri.parse(
      'https://www.openstreetmap.org/directions?engine=fossgis_osrm_car'
      '&route=${from.latitude},${from.longitude};${to.latitude},${to.longitude}',
    );
  }
}
