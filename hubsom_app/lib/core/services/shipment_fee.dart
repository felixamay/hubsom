import '../../models/product.dart';
import '../../models/user.dart';
import '../utils/money.dart';
import 'ghana_places.dart';

class ShipmentQuote {
  const ShipmentQuote({
    required this.feeGhs,
    required this.outOfRegion,
    required this.zoneLabel,
    this.productName = '',
  });

  final double feeGhs;
  final bool outOfRegion;
  final String zoneLabel;
  final String productName;

  String get lineLabel {
    final dest = zoneLabel.trim().isEmpty ? 'your pin' : zoneLabel.trim();
    if (outOfRegion) {
      return 'Out of region · $dest · ${formatGhs(feeGhs)}';
    }
    return '$dest · ${formatGhs(feeGhs)}';
  }
}

/// In-zone vs out-of-region shipment from the seller's selected cities.
abstract final class ShipmentFee {
  static const outOfRegionLabel = 'Out of region';

  static ShipmentQuote quote(
    Product product, {
    String? city,
    String? region,
    double? latitude,
    double? longitude,
    GeoLocation? location,
  }) {
    final lat = latitude ?? location?.latitude;
    final lng = longitude ?? location?.longitude;
    var destCity = (city ?? '').trim();
    if (destCity.isEmpty && lat != null && lng != null) {
      destCity = GhanaPlaces.nearest(lat, lng).city;
    }
    final inZone = GhanaPlaces.inShipmentZone(
      zoneCities: product.shipmentZoneCities,
      city: destCity,
      region: region,
      latitude: lat,
      longitude: lng,
    );
    if (inZone || !product.hasShipmentZones) {
      final fee = product.shipmentFeeGhs > 0
          ? product.shipmentFeeGhs
          : product.outOfRegionShipmentFeeGhs;
      return ShipmentQuote(
        feeGhs: fee < 0 ? 0 : fee,
        outOfRegion: false,
        zoneLabel: destCity.isEmpty
            ? (product.shipmentZoneCities.isEmpty
                ? 'Delivery'
                : product.shipmentZoneCities.first)
            : destCity,
        productName: product.name,
      );
    }
    final out = product.outOfRegionShipmentFeeGhs > 0
        ? product.outOfRegionShipmentFeeGhs
        : product.shipmentFeeGhs;
    return ShipmentQuote(
      feeGhs: out < 0 ? 0 : out,
      outOfRegion: true,
      zoneLabel: destCity.isEmpty ? outOfRegionLabel : destCity,
      productName: product.name,
    );
  }

  static String listingLabel(Product product) {
    if (!product.hasShipmentFee) return '';
    if (product.hasShipmentRange) {
      return 'ship ${formatGhs(product.minShipmentFeeGhs)}–${formatGhs(product.maxShipmentFeeGhs)}';
    }
    return 'ship ${formatGhs(product.minShipmentFeeGhs)}';
  }

  static String customerNotice({
    required String orderId,
    required List<ShipmentQuote> quotes,
    required double totalGhs,
  }) {
    if (quotes.isEmpty) {
      return 'Order $orderId is confirmed. The seller will share shipment next.';
    }
    final lines = quotes
        .map(
          (q) => q.productName.trim().isEmpty
              ? '• ${q.lineLabel}'
              : '• ${q.productName} — ${q.lineLabel}',
        )
        .join('\n');
    return 'Shipment for order $orderId\n$lines\nTotal ship ${formatGhs(totalGhs)}. Huber riders use this fee for your delivery.';
  }
}
