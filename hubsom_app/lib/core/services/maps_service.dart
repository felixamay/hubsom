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
}
