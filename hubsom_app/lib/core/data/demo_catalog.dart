import '../../models/product.dart';
import '../../models/promotion.dart';
import '../../models/seller.dart';
import '../../models/stream.dart';

/// Intentionally empty — Hubsom no longer ships seeded demo catalog/live data.
/// Products, sellers, and streams come from the API or the local commerce store.
abstract final class DemoCatalog {
  static const sellers = <Seller>[];
  static const products = <Product>[];
  static const promotions = <Promotion>[];
  static const streams = <LiveStream>[];

  static List<Product> productsFiltered({
    String? category,
    String? q,
    String? sellerId,
  }) {
    return const [];
  }
}
