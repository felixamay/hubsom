import '../../models/product.dart';
import '../../models/promotion.dart';
import '../../models/review.dart';
import '../../models/seller.dart';
import '../services/api_client.dart';
import '../services/local_store.dart';

class CatalogRepository {
  CatalogRepository(this._api);

  final ApiClient _api;

  Future<List<Product>> listProducts({
    String? category,
    String? q,
    String? sellerId,
    int? limit,
    int? offset,
  }) async {
    try {
      final res = await _api.get<dynamic>(
        '/api/products',
        queryParameters: {
          if (category != null) 'category': category,
          if (q != null && q.isNotEmpty) 'q': q,
          if (sellerId != null) 'sellerId': sellerId,
          if (limit != null) 'limit': limit,
          if (offset != null) 'offset': offset,
        },
      );
      final data = res.data;
      final list = data is List
          ? data
          : (data is Map && data['products'] is List)
              ? data['products'] as List
              : <dynamic>[];
      final products = list
          .map((e) => Product.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      await LocalStore.cacheJson('products', list);
      return products;
    } catch (_) {
      final cached = LocalStore.readCache('products');
      if (cached is List) {
        return cached
            .map((e) => Product.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      rethrow;
    }
  }

  Future<Product?> getProduct(String id) async {
    final products = await listProducts();
    try {
      return products.firstWhere((p) => p.id == id || p.slug == id);
    } catch (_) {
      return null;
    }
  }

  Future<List<Seller>> listSellers() async {
    final res = await _api.get<dynamic>('/api/sellers');
    final data = res.data;
    final list = data is List
        ? data
        : (data is Map && data['sellers'] is List)
            ? data['sellers'] as List
            : <dynamic>[];
    return list
        .map((e) => Seller.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Seller?> getSeller(String idOrSlug) async {
    final sellers = await listSellers();
    try {
      return sellers.firstWhere((s) => s.id == idOrSlug || s.slug == idOrSlug);
    } catch (_) {
      return null;
    }
  }

  Future<bool> toggleSave(String productId) async {
    final res = await _api.post<Map<String, dynamic>>('/api/products/$productId/save');
    return res.data?['saved'] as bool? ?? false;
  }

  Future<List<ProductReview>> listReviews(String productId) async {
    final res = await _api.get<dynamic>('/api/products/$productId/reviews');
    final data = res.data;
    final list = data is List
        ? data
        : (data is Map && data['reviews'] is List)
            ? data['reviews'] as List
            : <dynamic>[];
    return list
        .map((e) => ProductReview.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<ProductReview> submitReview(
    String productId, {
    required int rating,
    required String comment,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/api/products/$productId/reviews',
      data: {'rating': rating, 'comment': comment},
    );
    return ProductReview.fromJson(res.data ?? {});
  }

  Future<List<Promotion>> listPromotions(String placement) async {
    final res = await _api.get<dynamic>(
      '/api/promotions',
      queryParameters: {'placement': placement},
    );
    final data = res.data;
    final list = data is List
        ? data
        : (data is Map && data['promotions'] is List)
            ? data['promotions'] as List
            : <dynamic>[];
    return list
        .map((e) => Promotion.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<bool> followSeller(String sellerId) async {
    final res = await _api.post<Map<String, dynamic>>('/api/sellers/$sellerId/follow');
    return res.data?['following'] as bool? ?? false;
  }
}
