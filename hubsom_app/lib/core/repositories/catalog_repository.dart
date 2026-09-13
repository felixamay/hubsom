import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../models/product.dart';
import '../../models/product_social.dart';
import '../../models/promotion.dart';
import '../../models/purchase_offer.dart';
import '../../models/review.dart';
import '../../models/seller.dart';
import '../../models/shop_video.dart';
import '../../models/stream.dart';
import '../../models/user.dart';
import '../services/api_client.dart';
import '../services/api_response.dart';
import '../services/cloud_media.dart';
import '../services/cloud_store.dart';
import '../services/cloud_video_media.dart';
import '../services/video_frame_thumb.dart';
import '../services/local_blob_store.dart';
import '../services/local_commerce_store.dart';
import '../services/local_promotion_store.dart';
import '../services/local_purchase_offer_store.dart';
import '../services/local_store.dart';
import '../services/product_demo_video_store.dart';
import '../services/shop_video_cloud.dart';
import '../services/shop_video_tombstone.dart';
import '../services/video_for_slow_network.dart';

/// Cloud reads on the Home / feed path must never hold the UI on a slow link;
/// local data renders and the merge finishes in the background.
const _cloudMergeBudget = Duration(seconds: 6);

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
      if (ApiResponse.isHtml(raw)) {
        return local.where((p) => !p.isAuctionLot).toList();
      }

      final data = ApiResponse.decode(raw);
      if (data == null) return local.where((p) => !p.isAuctionLot).toList();

      final list = data is List
          ? data
          : (data is Map && data['products'] is List)
              ? data['products'] as List
              : <dynamic>[];

      if (list.isEmpty) return local.where((p) => !p.isAuctionLot).toList();

      final products = <Product>[];
      for (final e in list) {
        if (e is Map) {
          products.add(Product.fromJson(Map<String, dynamic>.from(e)));
        }
      }
      if (products.isEmpty) return local.where((p) => !p.isAuctionLot).toList();

      await LocalStore.cacheJson(
        'products',
        products.map((p) => p.toJson()).toList(),
      );
      return products.where((p) => !p.isAuctionLot).toList();
    } on DioException {
      return local.where((p) => !p.isAuctionLot).toList();
    } catch (_) {
      return local.where((p) => !p.isAuctionLot).toList();
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

  /// Pull cloud social data, but give up waiting after [_cloudMergeBudget] so
  /// a slow link never blanks Home or the feed. The merge keeps running and
  /// lands in local storage for the next read.
  Future<void> _mergeCloudSocialBounded() async {
    try {
      await LocalCommerceStore.mergeCloudSocial().timeout(_cloudMergeBudget);
    } catch (_) {}
  }

  Future<List<ShopVideo>> listShopVideos() async {
    await _mergeCloudSocialBounded();
    final list = LocalCommerceStore.listShopVideos();
    // Publish any local-only clips / thumbnails from this device. Do not
    // download other people's videos in the background — that saturates a
    // slow Ghana link before the clip the shopper is watching can start.
    // ignore: unawaited_futures
    _backfillShopVideoUrls(list);
    return list;
  }

  Future<List<ShopVideo>> myShopVideos() async {
    final user = _currentUser();
    if (user == null) return const [];
    await _mergeCloudSocialBounded();
    return LocalCommerceStore.listShopVideos()
        .where((v) => v.authorId == user.id)
        .toList();
  }

  /// Clips whose upload is running right now (Publish + Home backfill can
  /// both ask for the same video; never push the chunks twice).
  static final Set<String> _publishing = <String>{};

  Future<void> _backfillShopVideoUrls(List<ShopVideo> list) async {
    final user = _currentUser();
    final needs = list
        .where((v) => !v.hasPublishedMedia && !_publishing.contains(v.id))
        .where((v) => user == null || v.authorId == user.id)
        .take(4)
        .toList();
    for (final video in needs) {
      try {
        final stored = await ProductDemoVideoStore.load(video.id);
        if (stored == null) continue;
        await _publishShopVideoInBackground(
          videoId: video.id,
          bytes: stored.bytes,
          mimeType: stored.mimeType,
        );
      } catch (_) {}
    }
    await _backfillShopVideoThumbs(list);
  }

  /// Uploader's device: make sure every clip of mine has a still other
  /// phones can load. Missing stills are grabbed from the stored bytes;
  /// device-only blob refs are inlined into the Firestore doc.
  Future<void> _backfillShopVideoThumbs(List<ShopVideo> list) async {
    final user = _currentUser();
    if (user == null) return;
    final mine = list.where((v) => v.authorId == user.id).take(12);
    var pushed = 0;
    for (final video in mine) {
      if (pushed >= 4) break;
      try {
        final thumb = video.thumbnailUrl?.trim() ?? '';
        if (thumb.isEmpty) {
          final stored = await ProductDemoVideoStore.load(video.id);
          if (stored == null) continue;
          final frame = await captureShopVideoFrame(
            bytes: stored.bytes,
            mimeType: stored.mimeType,
          ).timeout(const Duration(seconds: 15), onTimeout: () => null);
          if (frame == null || frame.isEmpty) continue;
          final data = 'data:image/jpeg;base64,${base64Encode(frame)}';
          String ref;
          try {
            ref = await LocalBlobStore.putDataUrl(data);
          } catch (_) {
            ref = data;
          }
          await LocalCommerceStore.updateShopVideo(
            video.copyWith(thumbnailUrl: ref),
          );
          pushed++;
          continue;
        }
        if (LocalBlobStore.isRef(thumb) &&
            portableShopVideoThumb(thumb) != null &&
            !_thumbSynced.contains(video.id)) {
          await LocalCommerceStore.syncShopVideoToCloud(video);
          _thumbSynced.add(video.id);
          pushed++;
        }
      } catch (_) {}
    }
  }

  static final Set<String> _thumbSynced = <String>{};

  Future<ShopVideo?> getShopVideo(String id) async {
    await _mergeCloudSocialBounded();
    var video = LocalCommerceStore.getShopVideo(id);
    if (video == null) return null;
    if (!video.hasRemoteVideo) {
      await CloudVideoMedia.ensureLocalBytes(
        videoId: video.id,
        videoUrl: video.videoUrl,
        mimeType: video.mimeType,
      );
    }
    return LocalCommerceStore.getShopVideo(id) ?? video;
  }

  Future<ShopVideo> createShopVideo({
    required Uint8List bytes,
    required String mimeType,
    required List<String> productIds,
    String caption = '',
    String soundTitle = '',
    Uint8List? thumbnailBytes,
  }) async {
    final user = _currentUser();
    if (user == null) throw StateError('Sign in to upload a video');
    final prepared = await prepareShopVideoForSlowNetwork(
      bytes: bytes,
      mimeType: mimeType,
    );
    // Everything Publish waits on is local. Cloud writes (metadata, still,
    // video chunks) run in the background so a slow link never pins the
    // "Publishing video…" state.
    String? thumbUrl;
    if (thumbnailBytes != null && thumbnailBytes.isNotEmpty) {
      final data = 'data:image/jpeg;base64,${base64Encode(thumbnailBytes)}';
      try {
        thumbUrl = await LocalBlobStore.putDataUrl(data);
      } catch (_) {
        thumbUrl = data;
      }
    }
    final video = await LocalCommerceStore.createShopVideo(
      author: user,
      productIds: productIds,
      caption: caption,
      soundTitle: soundTitle,
      mimeType: prepared.mimeType,
      thumbnailUrl: thumbUrl,
      syncCloud: false,
    );
    await ProductDemoVideoStore.save(
      productId: video.id,
      bytes: prepared.bytes,
      mimeType: prepared.mimeType,
    );
    TimelinePost? post;
    try {
      Product? linked;
      for (final id in productIds) {
        linked = LocalCommerceStore.getProduct(id);
        if (linked != null) break;
      }
      post = await LocalCommerceStore.shareVideoToTimeline(
        video: video,
        author: user,
        linkedProduct: linked,
        caption: caption,
        syncCloud: false,
      );
    } catch (_) {}
    unawaited(
      _publishShopVideoInBackground(
        videoId: video.id,
        bytes: prepared.bytes,
        mimeType: prepared.mimeType,
        timelinePost: post,
      ),
    );
    return video;
  }

  Future<void> deleteShopVideo(String videoId) async {
    final user = _currentUser();
    if (user == null) throw StateError('Sign in to delete a video');
    final video = LocalCommerceStore.getShopVideo(videoId);
    if (video == null) throw StateError('Video not found');
    if (video.authorId != user.id) {
      throw StateError('You can only delete your own videos');
    }

    await LocalCommerceStore.deleteShopVideo(videoId);
    await ProductDemoVideoStore.remove(videoId);
    await _patchLikedVideo(videoId, false);
    await _patchSavedVideo(videoId, false);
    unawaited(_deleteShopVideoInBackground(videoId));
  }

  Future<void> _deleteShopVideoInBackground(String videoId) async {
    try {
      await CloudMedia.deleteShopVideoAssets(videoId: videoId);
      await CloudVideoMedia.deletePublished(videoId: videoId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CatalogRepository._deleteShopVideoInBackground: $e');
      }
    }
  }

  /// Cloud side of Publish, in order: metadata doc with the inline still (so
  /// Home on other phones shows the card at once), the timeline post, then
  /// the clip itself, then the doc again with the playable URL.
  Future<void> _publishShopVideoInBackground({
    required String videoId,
    required Uint8List bytes,
    required String mimeType,
    TimelinePost? timelinePost,
  }) async {
    if (!_publishing.add(videoId)) return;
    try {
      if (ShopVideoTombstones.contains(videoId)) return;
      final draft = LocalCommerceStore.getShopVideo(videoId);
      if (draft == null) return;
      await LocalCommerceStore.syncShopVideoToCloud(draft);
      if (ShopVideoTombstones.contains(videoId) ||
          LocalCommerceStore.getShopVideo(videoId) == null) {
        return;
      }
      _thumbSynced.add(videoId);
      if (timelinePost != null) {
        await LocalCommerceStore.syncTimelinePost(
          timelinePost.copyWith(
            videoThumbnailUrl: portableShopVideoThumb(draft.thumbnailUrl),
          ),
        );
      }

      final remoteUrl = await CloudVideoMedia.publish(
        videoId: videoId,
        bytes: bytes,
        mimeType: mimeType,
      ).timeout(const Duration(minutes: 20), onTimeout: () => null);
      if (remoteUrl == null || remoteUrl.isEmpty) return;
      if (ShopVideoTombstones.contains(videoId)) return;

      final current = LocalCommerceStore.getShopVideo(videoId);
      if (current == null) return;
      final patched = current.copyWith(videoUrl: remoteUrl);
      await LocalCommerceStore.updateShopVideo(patched);
      if (timelinePost != null) {
        await LocalCommerceStore.syncTimelinePost(
          timelinePost.copyWith(
            videoUrl: remoteUrl,
            videoThumbnailUrl: portableShopVideoThumb(patched.thumbnailUrl),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CatalogRepository._publishShopVideoInBackground: $e');
      }
    } finally {
      _publishing.remove(videoId);
    }
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
          if (!post.isLivePost && post.videoId == video.id) {
            final needUrl = (post.videoUrl == null || post.videoUrl!.isEmpty) &&
                video.videoUrl != null &&
                video.videoUrl!.isNotEmpty;
            final needThumb = (post.videoThumbnailUrl == null ||
                    post.videoThumbnailUrl!.isEmpty) &&
                video.thumbnailUrl != null &&
                video.thumbnailUrl!.isNotEmpty;
            if (needUrl || needThumb) {
              byId[entry.key] = post.copyWith(
                type: 'video',
                videoUrl: needUrl ? video.videoUrl : post.videoUrl,
                videoThumbnailUrl:
                    needThumb ? video.thumbnailUrl : post.videoThumbnailUrl,
              );
            }
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
        videoThumbnailUrl: video.thumbnailUrl,
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

    return TimelinePost.rankForFeed(byId.values);
  }

  /// Restore playable video posts when cloud docs lost type/videoId, or when the
  /// linked product has a local/remote demo clip.
  TimelinePost _healTimelineVideoPost(TimelinePost post) {
    if (post.isLivePost) return post;
    if (post.isVideo) {
      if ((post.type != 'video') ||
          (post.videoId == null || post.videoId!.isEmpty)) {
        return post.copyWith(
          type: 'video',
          videoId: post.videoId ?? post.productId,
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

    return post.copyWith(
      type: 'video',
      videoId: post.videoId ?? post.productId,
      videoUrl: post.videoUrl ?? product?.demoVideoUrl,
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
    LiveStream? stream,
  }) async {
    final user = _currentUser();
    if (user == null) throw StateError('Sign in to share to your timeline');
    var live = stream ?? LocalCommerceStore.getStream(streamId);
    if (live == null) {
      try {
        final rows = await CloudStore.listDocs(CloudStore.streams);
        for (final row in rows) {
          if ('${row['id']}' == streamId) {
            live = LiveStream.fromJson(row);
            await LocalCommerceStore.upsertStream(live);
            break;
          }
        }
      } catch (_) {}
    }
    if (live == null) throw StateError('Live show not found');
    Product? product;
    final pinId = live.pinnedProductId ?? live.auction?.productId;
    if (pinId != null && pinId.isNotEmpty) {
      product = await getProduct(pinId);
    }
    return LocalCommerceStore.shareLiveToTimeline(
      stream: live,
      author: user,
      product: product,
      caption: caption,
    );
  }

  Future<List<PurchaseOffer>> listPurchaseOffers() async {
    if (!CloudStore.useNetwork) {
      return LocalPurchaseOfferStore.all();
    }
    try {
      final res = await _api
          .get(
            '/api/promotions',
            queryParameters: {'placement': 'offers'},
          )
          .timeout(const Duration(seconds: 4));
      final data = ApiResponse.decode(res.data);
      if (data != null) {
        final list = data is List
            ? data
            : (data is Map && data['promotions'] is List)
                ? data['promotions'] as List
                : <dynamic>[];
        final remote = list
            .map(
              (e) =>
                  PurchaseOffer.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .where((o) => o.id.isNotEmpty && o.title.isNotEmpty)
            .toList();
        await LocalPurchaseOfferStore.mergeRemote(remote);
      }
    } catch (_) {}
    await LocalPurchaseOfferStore.pullCloud();
    return LocalPurchaseOfferStore.all();
  }

  Future<List<Promotion>> listPromotions(String placement) async {
    if (CloudStore.useNetwork) {
      try {
        final res = await _api
            .get(
              '/api/promotions',
              queryParameters: {'placement': placement},
            )
            .timeout(const Duration(seconds: 4));
        final data = ApiResponse.decode(res.data);
        if (data != null) {
          final list = data is List
              ? data
              : (data is Map && data['promotions'] is List)
                  ? data['promotions'] as List
                  : <dynamic>[];
          final remote = list
              .map(
                (e) => Promotion.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .where((p) => p.id.isNotEmpty && p.title.isNotEmpty)
              .toList();
          await LocalPromotionStore.mergeRemote(remote);
        }
      } catch (_) {}
      await LocalPromotionStore.pullCloud();
    }
    return LocalPromotionStore.forPlacement(placement);
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
