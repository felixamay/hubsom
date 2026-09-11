import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../models/user.dart';

class LocationDeniedException implements Exception {
  LocationDeniedException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Device GPS for sellers, buyers, and Huber riders (web + mobile).
class LocationService {
  LocationService({this.fetcher});

  /// Test hook — when set, skips the device geolocator plugin.
  final Future<GeoLocation> Function()? fetcher;

  Future<GeoLocation> current() async {
    if (fetcher != null) return fetcher!();
    return _fromDevice();
  }

  Future<GeoLocation> _fromDevice() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw LocationDeniedException(
        'Turn on location services so riders can navigate with GPS.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw LocationDeniedException(
        'Allow location access so riders can navigate to you.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw LocationDeniedException(
        'Location is blocked. Enable it in browser or device settings.',
      );
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
    return GeoLocation(
      latitude: pos.latitude,
      longitude: pos.longitude,
      accuracyM: pos.accuracy,
      source: 'gps',
      capturedAt: DateTime.now().toUtc().toIso8601String(),
    );
  }
}

extension GeoLocationMap on GeoLocation {
  LatLng get latLng => LatLng(latitude, longitude);
}
