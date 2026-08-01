import 'package:dio/dio.dart';

import '../../models/product.dart';
import '../../models/promotion.dart';
import '../../models/review.dart';
import '../../models/seller.dart';
import '../services/api_client.dart';
import '../services/api_response.dart';
import '../services/local_commerce_store.dart';
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
    final local = LocalCommerceStore.listProducts(
      category: category,
      q: q,
      sellerId: sellerId,
    );

    try {
      final res = await _api
          .get(
            '/api/products',
            queryParameters: {
              if (category != null) 'category': category,
              if (q != null && q.isNotEmpty) 'q': q,
              if (sellerId != null) 'sellerId': sellerId,
              if (limit != null) 'limit': limit,
              if (offset != null) 'offset': offset,
            },
          )
          .timeout(const Duration(seconds: 4));

      final raw = res.data;
      if (ApiResponse.isHtml(raw)) return local;

      final data = ApiResponse.decode(raw);
      if (data == null) return local;

      final list = data is List
          ? data
          : (data is Map && data['products'] is List)
              ? data['products'] as List
              : <dynamic>[];

      if (list.isEmpty) return local;

      final products = <Product>[];
      for (final e in list) {
        if (e is Map) {
          products.add(Product.fromJson(Map<String, dynamic>.from(e)));
        }
      }
      if (products.isEmpty) return local;

      await LocalStore.cacheJson(
        'products',
        products.map((p) => p.toJson()).toList(),
      );
      return products;
    } on DioException {
      return local;
    } catch (_) {
      return local;
    }
  }

  Future<Product?> getProduct(String id) async {
    final local = LocalCommerceStore.getProduct(id);
    if (local != null) return local;
    final products = await listProducts();
    try {
      return products.firstWhere((p) => p.id == id || p.slug == id);
    } catch (_) {
      return null;
    }
  }

  Future<List<Seller>> listSellers() async {
    final local = LocalCommerceStore.listSellers();
    try {
      final res =
          await _api.get('/api/sellers').timeout(const Duration(seconds: 4));
      final data = ApiResponse.decode(res.data);
      if (data == null) return local;
      final list = data is List
          ? data
          : (data is Map && data['sellers'] is List)
              ? data['sellers'] as List
              : <dynamic>[];
      if (list.isEmpty) return local;
      return list
          .map((e) => Seller.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return local;
    }
  }

  Future<Seller?> getSeller(String idOrSlug) async {
    final local = LocalCommerceStore.getSeller(idOrSlug);
    if (local != null) return local;
    final sellers = await listSellers();
    try {
      return sellers.firstWhere((s) => s.id == idOrSlug || s.slug == idOrSlug);
    } catch (_) {
      return null;
    }
  }

  Future<bool> toggleSave(String productId) async {
    try {
      final res = await _api.post('/api/products/$productId/save');
      return ApiResponse.asMap(res.data)?['saved'] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<List<ProductReview>> listReviews(String productId) async {
    try {
      final res = await _api.get('/api/products/$productId/reviews');
      final data = ApiResponse.decode(res.data);
      if (data == null) return const [];
      final list = data is List
          ? data
          : (data is Map && data['reviews'] is List)
              ? data['reviews'] as List
              : <dynamic>[];
      return list
          .map((e) => ProductReview.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<ProductReview> submitReview(
    String productId, {
    required int rating,
    required String comment,
  }) async {
    final res = await _api.post(
      '/api/products/$productId/reviews',
      data: {'rating': rating, 'comment': comment},
    );
    final data = ApiResponse.asMap(res.data);
    if (data == null) throw StateError('Review submit failed');
    return ProductReview.fromJson(data);
  }

  Future<List<Promotion>> listPromotions(String placement) async {
    try {
      final res = await _api
          .get(
            '/api/promotions',
            queryParameters: {'placement': placement},
          )
          .timeout(const Duration(seconds: 4));
      final data = ApiResponse.decode(res.data);
      if (data == null) return const [];
      final list = data is List
          ? data
          : (data is Map && data['promotions'] is List)
              ? data['promotions'] as List
              : <dynamic>[];
      return list
          .map((e) => Promotion.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<bool> followSeller(String sellerId) async {
    try {
      final res = await _api.post('/api/sellers/$sellerId/follow');
      return ApiResponse.asMap(res.data)?['following'] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }
}
