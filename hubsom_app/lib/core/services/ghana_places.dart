import 'package:latlong2/latlong.dart';

import 'maps_service.dart';

/// Approximate Ghana city / area coordinates for pickup distance.
abstract final class GhanaPlaces {
  static const _cities = <String, LatLng>{
    'accra': LatLng(5.6037, -0.1870),
    'osu': LatLng(5.5550, -0.1820),
    'labone': LatLng(5.5650, -0.1730),
    'cantonments': LatLng(5.5750, -0.1730),
    'east legon': LatLng(5.6360, -0.1510),
    'madina': LatLng(5.6833, -0.1667),
    'adenta': LatLng(5.7080, -0.1680),
    'tema': LatLng(5.6667, -0.0167),
    'ashaiman': LatLng(5.6990, -0.0333),
    'spintex': LatLng(5.6360, -0.0820),
    'kasoa': LatLng(5.5342, -0.4168),
    'dansoman': LatLng(5.5450, -0.2680),
    'achimota': LatLng(5.6170, -0.2320),
    'kumasi': LatLng(6.6885, -1.6244),
    'obuasi': LatLng(6.2023, -1.6678),
    'tamale': LatLng(9.4034, -0.8424),
    'cape coast': LatLng(5.1053, -1.2466),
    'takoradi': LatLng(4.8845, -1.7554),
    'sekondi': LatLng(4.9340, -1.7130),
    'sunyani': LatLng(7.3399, -2.3268),
    'techiman': LatLng(7.5905, -1.9395),
    'ho': LatLng(6.6008, 0.4713),
    'koforidua': LatLng(6.0940, -0.2591),
    'wa': LatLng(10.0601, -2.5099),
    'bolgatanga': LatLng(10.7856, -0.8514),
    'tarkwa': LatLng(5.3037, -1.9951),
    'winneba': LatLng(5.3511, -0.6231),
    'nkawkaw': LatLng(6.5512, -0.7662),
  };

  static const _regions = <String, LatLng>{
    'greater accra': LatLng(5.6037, -0.1870),
    'ashanti': LatLng(6.6885, -1.6244),
    'central': LatLng(5.1053, -1.2466),
    'western': LatLng(4.8845, -1.7554),
    'western north': LatLng(6.2000, -2.4800),
    'eastern': LatLng(6.0940, -0.2591),
    'volta': LatLng(6.6008, 0.4713),
    'oti': LatLng(8.1500, 0.3000),
    'northern': LatLng(9.4034, -0.8424),
    'north east': LatLng(10.3500, -0.5000),
    'savannah': LatLng(9.0833, -1.8167),
    'upper east': LatLng(10.7856, -0.8514),
    'upper west': LatLng(10.0601, -2.5099),
    'bono': LatLng(7.3399, -2.3268),
    'bono east': LatLng(7.5905, -1.9395),
    'ahafo': LatLng(7.0000, -2.3500),
  };

  static String _norm(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static LatLng resolve({
    String? address,
    String? city,
    String? region,
    double? latitude,
    double? longitude,
  }) {
    if (latitude != null && longitude != null) {
      return LatLng(latitude, longitude);
    }
    final haystack = [
      if ((address ?? '').trim().isNotEmpty) _norm(address!),
      if ((city ?? '').trim().isNotEmpty) _norm(city!),
    ];
    for (final text in haystack) {
      for (final entry in _cities.entries) {
        if (text == entry.key || text.contains(entry.key)) return entry.value;
      }
    }
    final r = _norm(region ?? '');
    if (r.isNotEmpty && _regions.containsKey(r)) return _regions[r]!;
    return MapsService.defaultCenter;
  }

  static double distanceKm(LatLng from, LatLng to) {
    return const Distance().as(LengthUnit.Kilometer, from, to);
  }

  static String formatDistanceKm(double km) {
    if (km < 0.1) return 'Under 100 m';
    if (km < 1) return '${(km * 1000).round()} m';
    if (km < 10) return '${km.toStringAsFixed(1)} km';
    return '${km.round()} km';
  }
}
