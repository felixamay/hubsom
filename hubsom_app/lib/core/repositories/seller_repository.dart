import 'dart:convert';

import '../../models/product.dart';
import '../../models/seller.dart';
import '../../models/user.dart';
import '../services/api_client.dart';
import '../services/api_response.dart';
import '../services/cloud_store.dart';
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
    final user = _user;
    if (user == null) return null;
    // Local seller profile is authoritative on Firebase Hosting (no API).
    final local = await LocalCommerceStore.ensureSellerForUser(user);
    try {
      final res = await _api.get('/api/seller/store');
      final data = ApiResponse.asMap(res.data);
      if (data != null && data.isNotEmpty && data['id'] != null) {
        final remote = Seller.fromJson(data);
        await LocalCommerceStore.upsertSeller(remote);
        return remote;
      }
    } catch (_) {
      // fall through
    }
    return local;
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

    final user = _user;
    if (user == null) throw AuthException('Sign in required');

    // Always write the local catalog first so Go live can see the product even
    // when Firebase Hosting has no /api/products backend.
    Product product;
    try {
      product = await LocalCommerceStore.createProduct(
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
    } catch (e) {
      final message = '$e';
      if (message.toLowerCase().contains('quota')) {
        throw AuthException(
          'This browser is out of storage space for product photos. Remove old listings or use fewer/smaller photos, then try again.',
        );
      }
      rethrow;
    }

    if (user.sellerId == null ||
        user.sellerId!.isEmpty ||
        user.sellerId != product.sellerId ||
        user.role == 'buyer') {
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
        sellerId: product.sellerId,
        huberId: user.huberId,
        followingSellerIds: user.followingSellerIds,
        savedProductIds: user.savedProductIds,
        addresses: user.addresses,
        emailVerified: user.emailVerified,
        walletBalanceGhs: user.walletBalanceGhs,
      );
      await LocalStore.setUserJson(jsonEncode(patched.toJson()));
    }

    try {
      await CloudStore.upsertDocs(CloudStore.products, [product.toJson()]);
      final seller = LocalCommerceStore.getSeller(product.sellerId);
      if (seller != null) {
        await CloudStore.upsertDocs(CloudStore.sellers, [seller.toJson()]);
      }
    } catch (_) {
      // Local catalog is enough to go live on this device.
    }

    try {
      final res = await _api.post('/api/products', data: {
        ...body,
        'id': product.id,
        'slug': product.slug,
        'sellerId': product.sellerId,
      });
      final data = ApiResponse.asMap(res.data);
      final remote = data?['product'] as Map? ?? data;
      if (remote != null && remote['id'] != null) {
        return Map<String, dynamic>.from(remote);
      }
    } catch (_) {
      // Hosting SPA has no API — local product already saved.
    }

    return product.toJson();
  }

  Future<List<Product>> myProducts() async {
    final user = _user;
    if (user == null) return const [];
    final seller = await LocalCommerceStore.ensureSellerForUser(user);
    final local = LocalCommerceStore.listProducts(sellerId: seller.id);

    try {
      final remoteRows = await CloudStore.listDocs(CloudStore.products);
      final remote = <Product>[];
      for (final row in remoteRows) {
        try {
          if ('${row['sellerId']}' != seller.id) continue;
          remote.add(Product.fromJson(row));
        } catch (_) {}
      }
      if (remote.isEmpty) return local;
      final byId = <String, Product>{
        for (final p in remote) p.id: p,
        for (final p in local) p.id: p,
      };
      return byId.values.toList();
    } catch (_) {
      return local;
    }
  }

  Future<Map<String, dynamic>> social(String sellerId) async {
    final res = await _api.get('/api/sellers/$sellerId/social');
    return ApiResponse.asMap(res.data) ?? {};
  }
}
