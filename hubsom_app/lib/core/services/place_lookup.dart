import 'package:dio/dio.dart';

import '../../models/user.dart';
import 'cloud_store.dart';
import 'ghana_places.dart';

class ResolvedPlace {
  const ResolvedPlace({
    required this.line1,
    this.city = '',
    this.region = '',
  });

  final String line1;
  final String city;
  final String region;

  String get displayLine {
    if (line1.trim().isNotEmpty && !UserAddress.looksLikeCoordinates(line1)) {
      return line1.trim();
    }
    return [city, region]
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .join(', ');
  }
}

/// Reverse-geocode a GPS pin to a real place name (street / city / region).
abstract final class PlaceLookup {
  /// Test hook — when set, skips Nominatim and the Ghana fallback.
  static Future<ResolvedPlace> Function(GeoLocation pin)? lookup;

  static Future<ResolvedPlace> reverse(GeoLocation pin) async {
    final hook = lookup;
    if (hook != null) return hook(pin);
    if (CloudStore.useNetwork) {
      try {
        final remote = await fromNominatim(pin);
        if (remote != null && remote.displayLine.isNotEmpty) return remote;
      } catch (_) {}
    }
    return fromLocal(pin);
  }

  static ResolvedPlace fromLocal(GeoLocation pin) {
    final near = GhanaPlaces.nearest(pin.latitude, pin.longitude);
    final line1 = [
      if (near.city.isNotEmpty) near.city,
      if (near.region.isNotEmpty && near.region != near.city) near.region,
    ].join(', ');
    return ResolvedPlace(line1: line1, city: near.city, region: near.region);
  }

  static Future<ResolvedPlace?> fromNominatim(
    GeoLocation pin, {
    Dio? dio,
    Map<String, dynamic>? json,
  }) async {
    final data = json ?? await _fetchNominatim(pin, dio ?? Dio());
    if (data == null) return null;
    return fromNominatimJson(data);
  }

  static ResolvedPlace? fromNominatimJson(Map<String, dynamic> data) {
    final raw = data['address'];
    final address = raw is Map
        ? Map<String, dynamic>.from(raw)
        : const <String, dynamic>{};
    final street = [
      '${address['house_number'] ?? ''}'.trim(),
      '${address['road'] ?? address['pedestrian'] ?? address['path'] ?? ''}'
          .trim(),
    ].where((e) => e.isNotEmpty).join(' ');
    final city = _firstAddress(address, const [
      'city',
      'town',
      'village',
      'municipality',
      'city_district',
      'suburb',
      'county',
    ]);
    final region = _firstAddress(address, const [
      'state',
      'region',
      'state_district',
    ]);
    final line1 = [
      if (street.isNotEmpty) street,
      if (city.isNotEmpty) city,
      if (region.isNotEmpty && region != city) region,
    ].join(', ');
    if (line1.isNotEmpty) {
      return ResolvedPlace(line1: line1, city: city, region: region);
    }
    final display = '${data['display_name'] ?? ''}'.trim();
    if (display.isEmpty) return null;
    final parts = display.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
    return ResolvedPlace(
      line1: parts.take(3).join(', '),
      city: city,
      region: region,
    );
  }

  static String _firstAddress(Map<String, dynamic> address, List<String> keys) {
    for (final key in keys) {
      final value = '${address[key] ?? ''}'.trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static Future<Map<String, dynamic>?> _fetchNominatim(
    GeoLocation pin,
    Dio dio,
  ) async {
    final res = await dio.get<Map<String, dynamic>>(
      'https://nominatim.openstreetmap.org/reverse',
      queryParameters: {
        'lat': pin.latitude,
        'lon': pin.longitude,
        'format': 'jsonv2',
        'addressdetails': 1,
        'zoom': 16,
      },
      options: Options(
        headers: const {
          'User-Agent': 'Hubsom/1.0 (https://hubsom.com; address lookup)',
          'Accept-Language': 'en',
        },
        responseType: ResponseType.json,
      ),
    );
    final data = res.data;
    if (data == null || data.isEmpty) return null;
    return data;
  }
}
