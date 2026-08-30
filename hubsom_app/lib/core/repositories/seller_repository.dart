import 'dart:convert';

import '../../models/product.dart';
import '../../models/seller.dart';
import '../../models/user.dart';
import '../services/api_client.dart';
import '../services/api_response.dart';
import '../services/local_commerce_store.dart';
import '../services/local_store.dart';
import 'auth_repository.dart';

class SellerRepository {
  SellerRepository(this._api);

  final ApiClient _api;

  HubsomUser? get _user {
    final raw = LocalStore.userJson;
    if (raw == null || raw.isEmpty) return null;
    try {
      return HubsomUser.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  Future<Seller?> myStore() async {
    try {
      final res = await _api.get('/api/seller/store');
      final data = ApiResponse.asMap(res.data);
      if (data != null && data.isNotEmpty && data['id'] != null) {
        return Seller.fromJson(data);
      }
    } catch (_) {
      // fall through
    }
    final user = _user;
    if (user == null) return null;
    return LocalCommerceStore.ensureSellerForUser(user);
  }

  Future<Seller> updateStore(Map<String, dynamic> body) async {
    try {
      final res = await _api.put('/api/seller/store', data: body);
      final data = ApiResponse.asMap(res.data);
      if (data != null) return Seller.fromJson(data);
    } catch (_) {
      // fall through
    }
    final user = _user;
    if (user == null) throw AuthException('Sign in required');
    final current = await LocalCommerceStore.ensureSellerForUser(user);
    final updated = Seller(
      id: current.id,
      slug: current.slug,
      name: body['name'] as String? ?? current.name,
      city: body['city'] as String? ?? current.city,
      region: body['region'] as String? ?? current.region,
      bio: body['bio'] as String? ?? current.bio,
      avatar: body['avatar'] as String? ?? current.avatar,
      cover: body['cover'] as String? ?? current.cover,
      rating: current.rating,
      followers: current.followers,
      verified: current.verified,
      categories: (body['categories'] as List?)?.cast<String>() ??
          current.categories,
      ownerUserId: current.ownerUserId,
    );
    return LocalCommerceStore.upsertSeller(updated);
  }

  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> body) async {
    final images = (body['images'] as List?)?.cast<String>() ?? const <String>[];
    if (images.length < 3) {
      throw AuthException('Upload at least 3 product photos before publishing');
    }

    try {
      final res = await _api.post('/api/products', data: body);
      final data = ApiResponse.asMap(res.data);
      final product = data?['product'] as Map? ?? data;
      if (product != null && product['id'] != null) {
        return Map<String, dynamic>.from(product);
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      // fall through to local store when API is unavailable
    }
    final user = _user;
    if (user == null) throw AuthException('Sign in required');
    final product = await LocalCommerceStore.createProduct(
      user: user,
      name: body['name'] as String? ?? 'Untitled',
      description: body['description'] as String? ?? '',
      category: body['category'] as String? ?? 'miscellaneous',
      priceGhs: (body['priceGhs'] as num?)?.toDouble() ?? 0,
      stock: (body['stock'] as num?)?.toInt() ?? 0,
      images: images,
      supports: (body['supports'] as List?)?.cast<String>() ??
          const ['buy-now', 'store-listing', 'live-selling', 'live-auction'],
    );
    // Persist sellerId on user for host checks.
    if (user.sellerId == null || user.sellerId!.isEmpty) {
      final seller = LocalCommerceStore.getSeller(product.sellerId);
      if (seller != null) {
        final patched = HubsomUser(
          id: user.id,
          email: user.email,
          name: user.name,
          image: user.image,
          phone: user.phone,
          city: user.city,
          region: user.region,
          bio: user.bio,
          role: user.role == 'buyer' ? 'both' : user.role,
          sellerId: seller.id,
          huberId: user.huberId,
          followingSellerIds: user.followingSellerIds,
          savedProductIds: user.savedProductIds,
          addresses: user.addresses,
          emailVerified: user.emailVerified,
          walletBalanceGhs: user.walletBalanceGhs,
        );
        await LocalStore.setUserJson(jsonEncode(patched.toJson()));
      }
    }
    return product.toJson();
  }

  Future<List<Product>> myProducts() async {
    final store = await myStore();
    if (store == null) return const [];
    return LocalCommerceStore.listProducts(sellerId: store.id);
  }

  Future<Map<String, dynamic>> social(String sellerId) async {
    final res = await _api.get('/api/sellers/$sellerId/social');
    return ApiResponse.asMap(res.data) ?? {};
  }
}
