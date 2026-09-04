import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../models/product.dart';
import '../../models/product_social.dart';
import '../../models/promotion.dart';
import '../../models/review.dart';
import '../../models/seller.dart';
import '../../models/shop_video.dart';
import '../../models/user.dart';
import '../services/api_client.dart';
import '../services/api_response.dart';
import '../services/cloud_store.dart';
import '../services/local_commerce_store.dart';
import '../services/local_store.dart';
import '../services/product_demo_video_store.dart';

class CatalogRepository {
  CatalogRepository(
    this._api, {
    void Function(HubsomUser user)? onUserChanged,
  }) : _onUserChanged = onUserChanged;

  final ApiClient _api;
  final void Function(HubsomUser user)? _onUserChanged;

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
      final saved = ApiResponse.asMap(res.data)?['saved'] as bool?;
      if (saved != null) {
        await _patchSaved(productId, saved);
        return saved;
      }
    } catch (_) {
      // fall through to local wishlist
    }
    final user = _currentUser();
    if (user == null) return false;
    final next = !user.savedProductIds.contains(productId);
    await _patchSaved(productId, next);
    return next;
  }

  bool isSaved(String productId) {
    final user = _currentUser();
    if (user == null) return false;
    return user.savedProductIds.contains(productId);
  }

  Future<bool> toggleLike(String productId) async {
    final user = _currentUser();
    if (user == null) return false;
    try {
      final res = await _api.post('/api/products/$productId/like');
      final liked = ApiResponse.asMap(res.data)?['liked'] as bool?;
      if (liked != null) {
        await _patchLiked(productId, liked);
        final localLiked = LocalCommerceStore.isLikedBy(productId, user.id);
        if (localLiked != liked) {
          await LocalCommerceStore.toggleProductLike(
            productId: productId,
            userId: user.id,
          );
        }
        return liked;
      }
    } catch (_) {
      // local like graph
    }
    await LocalCommerceStore.toggleProductLike(
      productId: productId,
      userId: user.id,
    );
    final liked = LocalCommerceStore.isLikedBy(productId, user.id);
    await _patchLiked(productId, liked);
    return liked;
  }

  bool isLiked(String productId) {
    final user = _currentUser();
    if (user == null) return false;
    return user.likedProductIds.contains(productId) ||
        LocalCommerceStore.isLikedBy(productId, user.id);
  }

  int likeCount(String productId) => LocalCommerceStore.likeCount(productId);

  Future<List<ProductComment>> listComments(String productId) async {
    await LocalCommerceStore.mergeCloudSocial();
    try {
      final res = await _api.get('/api/products/$productId/comments');
      final list = ApiResponse.asList(res.data, key: 'comments');
      if (list.isNotEmpty) {
        return list
            .map(
              (e) => ProductComment.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      }
    } catch (_) {}
    return LocalCommerceStore.listComments(productId);
  }

  Future<ProductComment> addComment(String productId, String text) async {
    final user = _currentUser();
    if (user == null) throw StateError('Sign in to comment');
    try {
      final res = await _api.post(
        '/api/products/$productId/comments',
        data: {'text': text},
      );
      final data = ApiResponse.asMap(res.data);
      final msg = data?['comment'] as Map? ?? data;
      if (msg != null && msg['id'] != null) {
        return ProductComment.fromJson(Map<String, dynamic>.from(msg));
      }
    } catch (_) {}
    return LocalCommerceStore.addComment(
      productId: productId,
      user: user,
      text: text,
    );
  }

  Future<List<ProductReview>> listReviews(String productId) async {
    await LocalCommerceStore.mergeCloudSocial();
    try {
      final res = await _api.get('/api/products/$productId/reviews');
      final data = ApiResponse.decode(res.data);
      if (data != null) {
        final list = data is List
            ? data
            : (data is Map && data['reviews'] is List)
                ? data['reviews'] as List
                : <dynamic>[];
        if (list.isNotEmpty) {
          return list
              .map(
                (e) => ProductReview.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      }
    } catch (_) {}
    return LocalCommerceStore.listReviews(productId);
  }

  Future<ProductReview> submitReview(
    String productId, {
    required int rating,
    required String comment,
  }) async {
    final user = _currentUser();
    if (user == null) throw StateError('Sign in to leave a review');
    try {
      final res = await _api.post(
        '/api/products/$productId/reviews',
        data: {'rating': rating, 'comment': comment},
      );
      final data = ApiResponse.asMap(res.data);
      if (data != null && data['id'] != null) {
        return ProductReview.fromJson(data);
      }
    } catch (_) {}
    return LocalCommerceStore.addReview(
      productId: productId,
      user: user,
      rating: rating,
      comment: comment,
    );
  }

  Future<List<ShopVideo>> listShopVideos() async {
    await LocalCommerceStore.mergeCloudSocial();
    return LocalCommerceStore.listShopVideos();
  }

  Future<ShopVideo?> getShopVideo(String id) async {
    await LocalCommerceStore.mergeCloudSocial();
    return LocalCommerceStore.getShopVideo(id);
  }

  Future<ShopVideo> createShopVideo({
    required Uint8List bytes,
    required String mimeType,
    required List<String> productIds,
    String caption = '',
    String soundTitle = '',
  }) async {
    final user = _currentUser();
    if (user == null) throw StateError('Sign in to upload a video');
    final video = await LocalCommerceStore.createShopVideo(
      author: user,
      productIds: productIds,
      caption: caption,
      soundTitle: soundTitle,
      mimeType: mimeType,
    );
    await ProductDemoVideoStore.save(
      productId: video.id,
      bytes: bytes,
      mimeType: mimeType,
    );
    // Post new videos to the vertical timeline feed.
    try {
      Product? linked;
      for (final id in productIds) {
        linked = await getProduct(id);
        if (linked != null) break;
      }
      await LocalCommerceStore.shareVideoToTimeline(
        video: video,
        author: user,
        linkedProduct: linked,
        caption: caption,
      );
    } catch (_) {}
    return video;
  }

  Future<bool> toggleVideoLike(String videoId) async {
    final user = _currentUser();
    if (user == null) return false;
    await LocalCommerceStore.toggleProductLike(
      productId: videoId,
      userId: user.id,
    );
    final liked = LocalCommerceStore.isLikedBy(videoId, user.id);
    await _patchLikedVideo(videoId, liked);
    return liked;
  }

  bool isVideoLiked(String videoId) {
    final user = _currentUser();
    if (user == null) return false;
    return user.likedVideoIds.contains(videoId) ||
        LocalCommerceStore.isLikedBy(videoId, user.id);
  }

  int videoLikeCount(String videoId) => LocalCommerceStore.likeCount(videoId);

  Future<bool> toggleVideoSave(String videoId) async {
    final user = _currentUser();
    if (user == null) return false;
    await LocalCommerceStore.toggleVideoSaveCount(
      videoId: videoId,
      userId: user.id,
    );
    final saved = LocalCommerceStore.isVideoSavedBy(videoId, user.id);
    await _patchSavedVideo(videoId, saved);
    return saved;
  }

  bool isVideoSaved(String videoId) {
    final user = _currentUser();
    if (user == null) return false;
    return user.savedVideoIds.contains(videoId) ||
        LocalCommerceStore.isVideoSavedBy(videoId, user.id);
  }

  int videoSaveCount(String videoId) =>
      LocalCommerceStore.videoSaveCount(videoId);

  Future<List<ProductComment>> listVideoComments(String videoId) async {
    await LocalCommerceStore.mergeCloudSocial();
    return LocalCommerceStore.listComments(videoId);
  }

  Future<ProductComment> addVideoComment(String videoId, String text) async {
    final user = _currentUser();
    if (user == null) throw StateError('Sign in to comment');
    return LocalCommerceStore.addComment(
      productId: videoId,
      user: user,
      text: text,
    );
  }

  int videoCommentCount(String videoId) =>
      LocalCommerceStore.listComments(videoId).length;

  Future<int> recordVideoShare(String videoId) async {
    return LocalCommerceStore.recordVideoShare(videoId);
  }

  Future<TimelinePost> shareVideoToTimeline(
    String videoId, {
    String caption = '',
  }) async {
    final user = _currentUser();
    if (user == null) throw StateError('Sign in to share to your timeline');
    final video = await getShopVideo(videoId);
    if (video == null) throw StateError('Video not found');
    Product? product;
    for (final id in video.productIds) {
      product = await getProduct(id);
      if (product != null) break;
    }
    final post = await LocalCommerceStore.shareVideoToTimeline(
      video: video,
      author: user,
      linkedProduct: product,
      caption: caption,
    );
    await recordVideoShare(videoId);
    return post;
  }

  Future<List<TimelinePost>> listTimeline() async {
    await LocalCommerceStore.mergeCloudSocial();
    final local = LocalCommerceStore.listTimelinePosts();
    final byId = <String, TimelinePost>{
      for (final p in local) p.id: p,
    };
    try {
      final rows = await CloudStore.listDocs(CloudStore.timelinePosts);
      for (final row in rows) {
        try {
          final p = TimelinePost.fromJson(row);
          byId[p.id] = p;
        } catch (_) {}
      }
    } catch (_) {}

    // Surface shop videos in the vertical timeline even if not shared yet.
    for (final video in LocalCommerceStore.listShopVideos()) {
      final already = byId.values.any((p) => p.videoId == video.id);
      if (already) continue;
      Product? linked;
      for (final id in video.productIds) {
        linked = LocalCommerceStore.getProduct(id);
        if (linked != null) break;
      }
      byId['video-${video.id}'] = TimelinePost(
        id: 'video-${video.id}',
        authorId: video.authorId,
        authorName: video.authorName,
        authorImage: video.authorImage,
        type: 'video',
        videoId: video.id,
        productId: linked?.id ??
            (video.productIds.isNotEmpty ? video.productIds.first : video.id),
        productName: linked?.name ??
            (video.caption.trim().isEmpty ? 'Shop video' : video.caption.trim()),
        productImage: linked?.images.isNotEmpty == true
            ? linked!.images.first
            : video.authorImage,
        caption: video.caption.trim().isEmpty
            ? 'Watch ${video.authorName} on Hubsom'
            : video.caption.trim(),
        createdAt: video.createdAt,
      );
    }

    final merged = byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }

  Future<TimelinePost> shareToTimeline(String productId, {String caption = ''}) async {
    final user = _currentUser();
    if (user == null) throw StateError('Sign in to share to your timeline');
    final product = await getProduct(productId);
    if (product == null) throw StateError('Product not found');
    return LocalCommerceStore.shareProductToTimeline(
      product: product,
      author: user,
      caption: caption,
    );
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
      final following = ApiResponse.asMap(res.data)?['following'] as bool?;
      if (following != null) {
        await _patchFollowing(sellerId, following);
        return following;
      }
    } catch (_) {
      // fall through to local follow list
    }
    if (_currentUser() == null) return false;
    await _patchFollowing(sellerId, true);
    return true;
  }

  Future<bool> unfollowSeller(String sellerId) async {
    try {
      final res = await _api.delete('/api/sellers/$sellerId/follow');
      final following = ApiResponse.asMap(res.data)?['following'] as bool?;
      if (following != null) {
        await _patchFollowing(sellerId, following);
        return following;
      }
    } catch (_) {
      // fall through
    }
    if (_currentUser() == null) return false;
    await _patchFollowing(sellerId, false);
    return false;
  }

  bool isFollowingSeller(String sellerId) {
    final user = _currentUser();
    if (user == null) return false;
    return user.followingSellerIds.contains(sellerId);
  }

  /// Followers of the signed-in user's store (or [sellerId] if provided).
  List<Map<String, dynamic>> listMyFollowers({String? sellerId}) {
    final id = sellerId ?? _currentUser()?.sellerId;
    if (id == null || id.isEmpty) {
      final user = _currentUser();
      if (user == null) return const [];
      final mine = LocalCommerceStore.listSellers()
          .where((s) => s.ownerUserId == user.id)
          .toList();
      if (mine.isEmpty) return const [];
      return LocalCommerceStore.listFollowers(mine.first.id);
    }
    return LocalCommerceStore.listFollowers(id);
  }

  int myFollowerCount({String? sellerId}) {
    final id = sellerId ?? _resolveMySellerId();
    if (id == null || id.isEmpty) return 0;
    return LocalCommerceStore.followerCount(id);
  }

  String? _resolveMySellerId() {
    final user = _currentUser();
    if (user == null) return null;
    if (user.sellerId != null && user.sellerId!.isNotEmpty) {
      return user.sellerId;
    }
    for (final s in LocalCommerceStore.listSellers()) {
      if (s.ownerUserId == user.id) return s.id;
    }
    return null;
  }

  HubsomUser? _currentUser() {
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

  Future<void> _persistUser(HubsomUser user) async {
    await LocalStore.setUserJson(jsonEncode(user.toJson()));
    final vault = LocalStore.loadCredentialVault();
    final key = user.email.toLowerCase();
    final entry = vault[key];
    if (entry is Map) {
      entry['userJson'] = user.toJson();
      vault[key] = entry;
      await LocalStore.saveCredentialVault(vault);
      try {
        await CloudStore.putAccount(key, {
          'salt': entry['salt'],
          'hash': entry['hash'],
          'userJson': user.toJson(),
          'email': key,
        });
      } catch (_) {}
    }
    _onUserChanged?.call(user);
  }

  Future<void> _patchFollowing(String sellerId, bool following) async {
    final user = _currentUser();
    if (user == null) return;
    final ids = [...user.followingSellerIds];
    if (following) {
      if (!ids.contains(sellerId)) ids.add(sellerId);
    } else {
      ids.remove(sellerId);
    }
    final updated = user.copyWith(followingSellerIds: ids);
    await _persistUser(updated);
    try {
      await LocalCommerceStore.setSellerFollowedBy(
        sellerId: sellerId,
        follower: updated,
        following: following,
      );
    } catch (_) {}
  }

  Future<void> _patchSaved(String productId, bool saved) async {
    final user = _currentUser();
    if (user == null) return;
    final ids = [...user.savedProductIds];
    if (saved) {
      if (!ids.contains(productId)) ids.add(productId);
    } else {
      ids.remove(productId);
    }
    await _persistUser(user.copyWith(savedProductIds: ids));
  }

  Future<void> _patchLiked(String productId, bool liked) async {
    final user = _currentUser();
    if (user == null) return;
    final ids = [...user.likedProductIds];
    if (liked) {
      if (!ids.contains(productId)) ids.add(productId);
    } else {
      ids.remove(productId);
    }
    await _persistUser(user.copyWith(likedProductIds: ids));
  }

  Future<void> _patchLikedVideo(String videoId, bool liked) async {
    final user = _currentUser();
    if (user == null) return;
    final ids = [...user.likedVideoIds];
    if (liked) {
      if (!ids.contains(videoId)) ids.add(videoId);
    } else {
      ids.remove(videoId);
    }
    await _persistUser(user.copyWith(likedVideoIds: ids));
  }

  Future<void> _patchSavedVideo(String videoId, bool saved) async {
    final user = _currentUser();
    if (user == null) return;
    final ids = [...user.savedVideoIds];
    if (saved) {
      if (!ids.contains(videoId)) ids.add(videoId);
    } else {
      ids.remove(videoId);
    }
    await _persistUser(user.copyWith(savedVideoIds: ids));
  }
}
