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
import '../services/cloud_video_media.dart';
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
      if (data == null) return _withLiveFollowerCounts(local);
      final list = data is List
          ? data
          : (data is Map && data['sellers'] is List)
              ? data['sellers'] as List
              : <dynamic>[];
      if (list.isEmpty) return _withLiveFollowerCounts(local);
      final remote = list
          .map((e) => Seller.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      // Prefer local rows when present so follower counts / photos stick.
      final byId = <String, Seller>{
        for (final s in remote) s.id: s,
      };
      for (final s in local) {
        byId[s.id] = s;
      }
      return _withLiveFollowerCounts(byId.values.toList());
    } catch (_) {
      return _withLiveFollowerCounts(local);
    }
  }

  Future<Seller?> getSeller(String idOrSlug) async {
    final local = LocalCommerceStore.getSeller(idOrSlug);
    if (local != null) return _withLiveFollowerCount(local);
    final sellers = await listSellers();
    try {
      final found =
          sellers.firstWhere((s) => s.id == idOrSlug || s.slug == idOrSlug);
      return _withLiveFollowerCount(found);
    } catch (_) {
      return null;
    }
  }

  /// Find a store owned by a Hubsom user (for follow-back / visit from Followers).
  Future<Seller?> getSellerByOwnerUserId(String userId) async {
    final local = LocalCommerceStore.getSellerByOwnerUserId(userId);
    if (local != null) return _withLiveFollowerCount(local);
    final sellers = await listSellers();
    try {
      final found = sellers.firstWhere((s) => s.ownerUserId == userId);
      return _withLiveFollowerCount(found);
    } catch (_) {
      return null;
    }
  }

  Seller _withLiveFollowerCount(Seller seller) {
    final count = LocalCommerceStore.followerCount(seller.id);
    if (count == seller.followers) return seller;
    return seller.copyWith(followers: count);
  }

  List<Seller> _withLiveFollowerCounts(List<Seller> sellers) =>
      sellers.map(_withLiveFollowerCount).toList();

  int sellerFollowerCount(String sellerId) =>
      LocalCommerceStore.followerCount(sellerId);

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
    try {
      await LocalCommerceStore.mergeCloudSocial();
    } catch (_) {}
    final list = LocalCommerceStore.listShopVideos();
    // Never block the homepage/timeline on media backfill — do it in background.
    // ignore: unawaited_futures
    _publishAndHydrateInBackground(list);
    return list;
  }

  Future<void> _publishAndHydrateInBackground(List<ShopVideo> list) async {
    try {
      await _backfillShopVideoUrls(list);
      final refreshed = LocalCommerceStore.listShopVideos();
      for (final video in refreshed.take(12)) {
        await CloudVideoMedia.ensureLocalBytes(
          videoId: video.id,
          videoUrl: video.videoUrl,
          mimeType: video.mimeType,
        );
      }
    } catch (_) {}
  }

  Future<void> _backfillShopVideoUrls(List<ShopVideo> list) async {
    final needs = list.where((v) => !v.hasPublishedMedia).take(8).toList();
    for (final video in needs) {
      try {
        final stored = await ProductDemoVideoStore.load(video.id);
        if (stored == null) continue;
        final url = await CloudVideoMedia.publish(
          videoId: video.id,
          bytes: stored.bytes,
          mimeType: stored.mimeType,
        );
        if (url == null || url.isEmpty) continue;
        await LocalCommerceStore.updateShopVideo(video.copyWith(videoUrl: url));
      } catch (_) {}
    }
  }

  Future<ShopVideo?> getShopVideo(String id) async {
    try {
      await LocalCommerceStore.mergeCloudSocial();
    } catch (_) {}
    var video = LocalCommerceStore.getShopVideo(id);
    if (video == null) return null;
    await CloudVideoMedia.ensureLocalBytes(
      videoId: video.id,
      videoUrl: video.videoUrl,
      mimeType: video.mimeType,
    );
    return LocalCommerceStore.getShopVideo(id) ?? video;
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
    // Create metadata first so we have a stable id, then upload media.
    final draft = await LocalCommerceStore.createShopVideo(
      author: user,
      productIds: productIds,
      caption: caption,
      soundTitle: soundTitle,
      mimeType: mimeType,
    );
    await ProductDemoVideoStore.save(
      productId: draft.id,
      bytes: bytes,
      mimeType: mimeType,
    );
    final remoteUrl = await CloudVideoMedia.publish(
      videoId: draft.id,
      bytes: bytes,
      mimeType: mimeType,
    );
    final video = remoteUrl == null || remoteUrl.isEmpty
        ? draft
        : (await LocalCommerceStore.updateShopVideo(
              draft.copyWith(videoUrl: remoteUrl),
            )) ??
            draft.copyWith(videoUrl: remoteUrl);
    // Force metadata to cloud even if media publish failed (other devices
    // still see the card; media hydrates when bytes become available).
    try {
      await CloudStore.upsertDocs(CloudStore.shopVideos, [video.toJson()]);
    } catch (_) {}
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
    try {
      await LocalCommerceStore.mergeCloudSocial();
    } catch (_) {}
    // Pull shop-video metadata into local cache before synthesizing the feed.
    try {
      await listShopVideos();
    } catch (_) {}

    final local = LocalCommerceStore.listTimelinePosts();
    final byId = <String, TimelinePost>{
      for (final p in local) p.id: p,
    };
    try {
      final rows = await CloudStore.listDocs(CloudStore.timelinePosts);
      for (final row in rows) {
        try {
          var p = TimelinePost.fromJson(row);
          // Heal older cloud posts that lost type/videoId after a partial write.
          p = _healTimelineVideoPost(p);
          byId[p.id] = p;
        } catch (_) {}
      }
    } catch (_) {}

    // Surface shop videos in the vertical timeline even if not shared yet.
    for (final video in LocalCommerceStore.listShopVideos()) {
      final already = byId.values.any((p) => p.videoId == video.id);
      if (already) {
        // Enrich existing posts with remote videoUrl when missing.
        for (final entry in byId.entries.toList()) {
          final post = entry.value;
          if (post.videoId == video.id &&
              (post.videoUrl == null || post.videoUrl!.isEmpty) &&
              video.videoUrl != null &&
              video.videoUrl!.isNotEmpty) {
            byId[entry.key] = TimelinePost(
              id: post.id,
              authorId: post.authorId,
              authorName: post.authorName,
              authorImage: post.authorImage,
              type: 'video',
              productId: post.productId,
              productName: post.productName,
              productImage: post.productImage,
              videoId: post.videoId,
              videoUrl: video.videoUrl,
              caption: post.caption,
              createdAt: post.createdAt,
            );
          }
        }
        continue;
      }
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
        videoUrl: video.videoUrl,
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

    // Product demo clips should also play on Timeline (bytes keyed by product id).
    for (final entry in byId.entries.toList()) {
      byId[entry.key] = _healTimelineVideoPost(entry.value);
    }

    final merged = byId.values.toList();
    // Shop videos first (newest first), then other posts — so Timeline matches
    // Home's Shop videos instead of burying clips under older product posts.
    final videoPosts = merged.where((p) => p.isVideo).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final otherPosts = merged.where((p) => !p.isVideo).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return [...videoPosts, ...otherPosts];
  }

  /// Restore playable video posts when cloud docs lost type/videoId, or when the
  /// linked product has a local/remote demo clip.
  TimelinePost _healTimelineVideoPost(TimelinePost post) {
    if (post.isVideo) {
      if ((post.type != 'video') ||
          (post.videoId == null || post.videoId!.isEmpty)) {
        return TimelinePost(
          id: post.id,
          authorId: post.authorId,
          authorName: post.authorName,
          authorImage: post.authorImage,
          type: 'video',
          productId: post.productId,
          productName: post.productName,
          productImage: post.productImage,
          videoId: post.videoId ?? post.productId,
          videoUrl: post.videoUrl,
          caption: post.caption,
          createdAt: post.createdAt,
        );
      }
      return post;
    }

    final product = post.productId.isEmpty
        ? null
        : LocalCommerceStore.getProduct(post.productId);
    final caption = post.caption.toLowerCase();
    final looksLikeVideo = caption.contains('video on hubsom') ||
        (caption.contains('watch ') && caption.contains('video'));
    final hasDemo = product?.showsDemoVideo == true;
    if (!looksLikeVideo && !hasDemo) return post;

    return TimelinePost(
      id: post.id,
      authorId: post.authorId,
      authorName: post.authorName,
      authorImage: post.authorImage,
      type: 'video',
      productId: post.productId,
      productName: post.productName,
      productImage: post.productImage,
      videoId: post.videoId ?? post.productId,
      videoUrl: post.videoUrl ?? product?.demoVideoUrl,
      caption: post.caption,
      createdAt: post.createdAt,
    );
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

  Future<TimelinePost> shareLiveToTimeline(
    String streamId, {
    String caption = '',
  }) async {
    final user = _currentUser();
    if (user == null) throw StateError('Sign in to share to your timeline');
    final stream = LocalCommerceStore.getStream(streamId);
    if (stream == null) throw StateError('Live show not found');
    Product? product;
    final pinId = stream.pinnedProductId ?? stream.auction?.productId;
    if (pinId != null && pinId.isNotEmpty) {
      product = await getProduct(pinId);
    }
    return LocalCommerceStore.shareLiveToTimeline(
      stream: stream,
      author: user,
      product: product,
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
    final ids = _mySellerIds(sellerId);
    if (ids.isEmpty) return const [];
    final byUser = <String, Map<String, dynamic>>{};
    for (final id in ids) {
      for (final row in LocalCommerceStore.listFollowers(id)) {
        final uid = '${row['userId']}';
        if (uid.isEmpty) continue;
        byUser.putIfAbsent(uid, () => row);
      }
    }
    final out = byUser.values.toList()
      ..sort((a, b) => '${b['at']}'.compareTo('${a['at']}'));
    return out;
  }

  int myFollowerCount({String? sellerId}) {
    return listMyFollowers(sellerId: sellerId).length;
  }

  Set<String> _mySellerIds(String? sellerId) {
    final ids = <String>{};
    if (sellerId != null && sellerId.isNotEmpty) ids.add(sellerId);
    final user = _currentUser();
    if (user == null) return ids;
    if (user.sellerId != null && user.sellerId!.isNotEmpty) {
      ids.add(user.sellerId!);
    }
    for (final s in LocalCommerceStore.listSellers()) {
      if (s.ownerUserId == user.id) ids.add(s.id);
    }
    return ids;
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
