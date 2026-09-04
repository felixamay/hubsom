import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/auth/require_auth.dart';
import '../../core/providers/core_providers.dart';
import '../../core/services/cloud_video_media.dart';
import '../../core/services/local_commerce_store.dart';
import '../../core/services/product_demo_video_store.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../models/product.dart';
import '../../models/product_social.dart';
import '../../models/shop_video.dart';
import '../../widgets/commerce_cta_bar.dart';
import '../../widgets/hubsom_image.dart';
import '../../widgets/product_demo_video_player.dart';

/// Vertical, one-at-a-time timeline of posted products and shop videos.
class TimelinePage extends ConsumerStatefulWidget {
  const TimelinePage({super.key});

  @override
  ConsumerState<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends ConsumerState<TimelinePage> {
  /// Non-video timeline posts (products / shares). Videos come from [shopVideosProvider].
  List<TimelinePost> _productPosts = const [];
  bool _bootstrapping = true;
  String? _error;
  late final PageController _pageCtrl;
  /// Avoid setState on every swipe — that rebuilt HtmlElementView and flickered.
  final ValueNotifier<int> _index = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _loadProductPosts(initial: true);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _index.dispose();
    super.dispose();
  }

  TimelinePost _postFromVideo(ShopVideo video) {
    Product? linked;
    for (final id in video.productIds) {
      linked = LocalCommerceStore.getProduct(id);
      if (linked != null) break;
    }
    return TimelinePost(
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
      productImage: linked != null && linked.images.isNotEmpty
          ? linked.images.first
          : video.authorImage,
      caption: video.caption.trim().isEmpty
          ? 'Watch ${video.authorName} on Hubsom'
          : video.caption.trim(),
      createdAt: video.createdAt,
    );
  }

  Future<void> _loadProductPosts({bool initial = false}) async {
    if (initial && mounted) {
      setState(() {
        _bootstrapping = true;
        _error = null;
      });
    }
    try {
      final all = await ref.read(catalogRepositoryProvider).listTimeline();
      if (!mounted) return;
      setState(() {
        // Keep healed video posts from listTimeline (not only shopVideosProvider).
        _productPosts = all;
        _bootstrapping = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _bootstrapping = false;
        _error = '$e';
      });
    }
  }

  List<TimelinePost> _composeFeed(List<ShopVideo> videos) {
    final byId = <String, TimelinePost>{
      for (final p in _productPosts) p.id: p,
    };
    for (final video in videos) {
      final synthesized = _postFromVideo(video);
      byId['video-${video.id}'] = synthesized;
      for (final entry in byId.entries.toList()) {
        final post = entry.value;
        if (post.videoId == video.id) {
          byId[entry.key] = TimelinePost(
            id: post.id,
            authorId: post.authorId,
            authorName: post.authorName,
            authorImage: post.authorImage,
            type: 'video',
            productId: post.productId.isNotEmpty
                ? post.productId
                : synthesized.productId,
            productName: post.productName.isNotEmpty
                ? post.productName
                : synthesized.productName,
            productImage: post.productImage ?? synthesized.productImage,
            videoId: video.id,
            videoUrl: video.videoUrl ?? post.videoUrl,
            caption: post.caption,
            createdAt: post.createdAt,
          );
        }
      }
    }
    final merged = byId.values.toList();
    final videoPosts = merged.where((p) => p.isVideo).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final others = merged.where((p) => !p.isVideo).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return [...videoPosts, ...others];
  }

  @override
  Widget build(BuildContext context) {
    final videosAsync = ref.watch(shopVideosProvider);
    final videos = videosAsync.valueOrNull ?? const <ShopVideo>[];
    final posts = _composeFeed(videos);
    final waitingFirstPaint =
        _bootstrapping && posts.isEmpty && videosAsync.isLoading;

    // Soft refresh product posts when opening Timeline — do not invalidate videos
    // (that remounts every player and causes flicker / blank video on desktop).
    ref.listen(timelineTabTickProvider, (previous, next) {
      if (previous != next) {
        _loadProductPosts(initial: false);
      }
    });
    ref.listen(shopVideosProvider, (previous, next) {
      next.whenData((videos) {
        final wasEmpty = previous?.valueOrNull?.isEmpty ?? true;
        if (wasEmpty && videos.isNotEmpty && _index.value == 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_pageCtrl.hasClients) return;
            _pageCtrl.jumpToPage(0);
          });
        }
      });
    });

    if (waitingFirstPaint) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_error != null && posts.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _loadProductPosts(initial: true),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (posts.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: _EmptyTimeline(
          onBrowse: () => context.go('/marketplace'),
          onAddVideo: () => context.push('/videos/upload'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageCtrl,
            scrollDirection: Axis.vertical,
            pageSnapping: true,
            allowImplicitScrolling: true,
            physics: const PageScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            itemCount: posts.length,
            onPageChanged: (i) {
              if (_index.value != i) _index.value = i;
            },
            itemBuilder: (_, i) {
              return ValueListenableBuilder<int>(
                valueListenable: _index,
                builder: (_, index, __) {
                  final safeIndex = index.clamp(0, posts.length - 1);
                  final nearby = (i - safeIndex).abs() <= 1;
                  return _TimelineSlide(
                    key: ValueKey(posts[i].id),
                    post: posts[i],
                    active: i == safeIndex,
                    keepMedia: nearby,
                  );
                },
              );
            },
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              tooltip: 'Refresh',
              onPressed: () {
                ref.invalidate(shopVideosProvider);
                _loadProductPosts(initial: false);
              },
              style: IconButton.styleFrom(
                backgroundColor: Colors.black45,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.refresh),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTimeline extends StatelessWidget {
  const _EmptyTimeline({required this.onBrowse, required this.onAddVideo});
  final VoidCallback onBrowse;
  final VoidCallback onAddVideo;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.dynamic_feed_outlined, size: 56, color: Colors.white54),
            const SizedBox(height: 16),
            const Text(
              'Nothing on the timeline yet',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Share a product or post a shop video — then swipe up for the next post.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onBrowse,
              child: const Text('Browse products'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: onAddVideo,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Add video'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineSlide extends ConsumerStatefulWidget {
  const _TimelineSlide({
    super.key,
    required this.post,
    required this.active,
    this.keepMedia = false,
  });

  final TimelinePost post;
  final bool active;
  /// Keep the player mounted for the current/adjacent slides to avoid swipe flicker.
  final bool keepMedia;

  @override
  ConsumerState<_TimelineSlide> createState() => _TimelineSlideState();
}

class _TimelineSlideState extends ConsumerState<_TimelineSlide>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  Product? _product;
  ShopVideo? _video;
  bool _liked = false;
  bool _saved = false;
  bool _following = false;
  int _likes = 0;
  int _comments = 0;
  int _saves = 0;
  int _shares = 0;
  bool _captionExpanded = false;
  late final AnimationController _discCtrl;
  late final AnimationController _heartBurst;
  Offset? _burstAt;

  @override
  bool get wantKeepAlive => widget.active || widget.keepMedia;

  bool get _isVideo =>
      widget.post.isVideo &&
      widget.post.videoId != null &&
      widget.post.videoId!.isNotEmpty;

  String get _socialId =>
      _isVideo ? widget.post.videoId! : widget.post.productId;

  String? get _sellerId {
    if (_video?.authorSellerId != null &&
        _video!.authorSellerId!.isNotEmpty) {
      return _video!.authorSellerId;
    }
    final sid = _product?.sellerId;
    if (sid != null && sid.isNotEmpty) return sid;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _discCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    _heartBurst = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    if (widget.active && _isVideo) _discCtrl.repeat();
    _bootstrap();
  }

  @override
  void didUpdateWidget(covariant _TimelineSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      _bootstrap();
    }
    if (oldWidget.active != widget.active ||
        oldWidget.keepMedia != widget.keepMedia) {
      updateKeepAlive();
    }
    if (widget.active && _isVideo && !_discCtrl.isAnimating) {
      _discCtrl.repeat();
    } else if ((!widget.active || !_isVideo) && _discCtrl.isAnimating) {
      _discCtrl.stop();
    }
  }

  @override
  void dispose() {
    _discCtrl.dispose();
    _heartBurst.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await Future.wait([_loadProduct(), _loadVideo()]);
    if (!mounted) return;
    _syncSocial();
  }

  Future<void> _loadProduct() async {
    final id = widget.post.productId;
    if (id.isEmpty) {
      if (mounted) setState(() => _product = null);
      return;
    }
    final p = await ref.read(catalogRepositoryProvider).getProduct(id);
    if (!mounted) return;
    setState(() => _product = p);
  }

  Future<void> _loadVideo() async {
    if (!_isVideo) {
      if (mounted) setState(() => _video = null);
      return;
    }
    final v =
        await ref.read(catalogRepositoryProvider).getShopVideo(widget.post.videoId!);
    if (!mounted) return;
    setState(() {
      _video = v;
      _shares = v?.shareCount ?? 0;
    });
  }

  void _syncSocial() {
    final catalog = ref.read(catalogRepositoryProvider);
    final id = _socialId;
    if (id.isEmpty) return;
    final sellerId = _sellerId ?? '';
    setState(() {
      if (_isVideo) {
        _liked = catalog.isVideoLiked(id);
        _saved = catalog.isVideoSaved(id);
        _likes = catalog.videoLikeCount(id);
        _comments = catalog.videoCommentCount(id);
        _saves = catalog.videoSaveCount(id);
        _shares = _video?.shareCount ?? 0;
      } else {
        _liked = catalog.isLiked(id);
        _saved = catalog.isSaved(id);
        _likes = catalog.likeCount(id);
        _comments = 0;
        _saves = 0;
        _shares = 0;
      }
      _following =
          sellerId.isNotEmpty && catalog.isFollowingSeller(sellerId);
    });
    if (!_isVideo && id.isNotEmpty) {
      catalog.listComments(id).then((list) {
        if (!mounted) return;
        setState(() => _comments = list.length);
      });
    }
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}K';
    return '$n';
  }

  Future<void> _toggleLike({Offset? at}) async {
    final id = _socialId;
    if (id.isEmpty) return;
    if (!ensureSignedIn(context, ref, message: 'Sign in to like')) return;
    final catalog = ref.read(catalogRepositoryProvider);
    final liked = _isVideo
        ? await catalog.toggleVideoLike(id)
        : await catalog.toggleLike(id);
    if (!mounted) return;
    setState(() {
      _liked = liked;
      _likes = _isVideo ? catalog.videoLikeCount(id) : catalog.likeCount(id);
    });
    if (liked) {
      _burstAt = at ??
          Offset(
            MediaQuery.sizeOf(context).width * 0.5,
            MediaQuery.sizeOf(context).height * 0.42,
          );
      _heartBurst
        ..reset()
        ..forward();
    }
  }

  Future<void> _toggleSave() async {
    final id = _socialId;
    if (id.isEmpty) return;
    if (!ensureSignedIn(context, ref, message: 'Sign in to save')) return;
    final catalog = ref.read(catalogRepositoryProvider);
    final saved = _isVideo
        ? await catalog.toggleVideoSave(id)
        : await catalog.toggleSave(id);
    if (!mounted) return;
    setState(() {
      _saved = saved;
      if (_isVideo) _saves = catalog.videoSaveCount(id);
    });
  }

  Future<void> _toggleFollow() async {
    final sellerId = _sellerId;
    if (sellerId == null || sellerId.isEmpty) return;
    if (!ensureSignedIn(context, ref, message: 'Sign in to follow')) return;
    final catalog = ref.read(catalogRepositoryProvider);
    final next = _following
        ? await catalog.unfollowSeller(sellerId)
        : await catalog.followSeller(sellerId);
    if (!mounted) return;
    setState(() => _following = next);
  }

  Future<void> _openComments() async {
    final id = _socialId;
    if (id.isEmpty) return;
    if (_isVideo) {
      await context.push('/videos/$id/comments');
      if (!mounted) return;
      setState(() {
        _comments =
            ref.read(catalogRepositoryProvider).videoCommentCount(id);
      });
      return;
    }
    await context.push('/products/$id/comments');
    if (!mounted) return;
    final list = await ref.read(catalogRepositoryProvider).listComments(id);
    if (!mounted) return;
    setState(() => _comments = list.length);
  }

  Future<void> _shareLink() async {
    final post = widget.post;
    if (_isVideo) {
      final vid = post.videoId!;
      await Share.share(
        'Watch ${post.authorName} on Hubsom: https://hubsom.com/videos/$vid',
        subject: post.authorName,
      );
      final count =
          await ref.read(catalogRepositoryProvider).recordVideoShare(vid);
      if (!mounted) return;
      setState(() {
        _shares = count;
        if (_video != null) _video = _video!.copyWith(shareCount: count);
      });
      return;
    }
    final pid = post.productId;
    if (pid.isEmpty) return;
    await Share.share(
      'Check out ${post.productName} on Hubsom: https://hubsom.com/products/$pid',
      subject: post.productName,
    );
  }

  Future<void> _shareMenu() async {
    if (!ensureSignedIn(context, ref, message: 'Sign in to share')) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.ios_share, color: Colors.white),
              title: const Text('Share link', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, 'link'),
            ),
            if (!_isVideo)
              ListTile(
                leading: const Icon(Icons.dynamic_feed, color: Colors.white),
                title: const Text(
                  'Post to timeline',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.pop(ctx, 'timeline'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'link') {
      await _shareLink();
      return;
    }
    final pid = widget.post.productId;
    if (pid.isEmpty) return;
    await ref.read(catalogRepositoryProvider).shareToTimeline(pid);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Shared to your timeline')),
    );
  }

  void _openAuthor() {
    final sellerId = _sellerId;
    if (sellerId == null || sellerId.isEmpty) return;
    context.push('/stores/$sellerId');
  }

  Future<void> _buyNow() async {
    final product = _product;
    if (product == null) {
      _openProduct();
      return;
    }
    if (!ensureSignedIn(context, ref, message: 'Sign in to buy')) return;
    await ref.read(cartProvider.notifier).addProduct(product, source: 'buy-now');
    if (!mounted) return;
    context.push('/checkout');
  }

  void _openProduct() {
    final id = widget.post.productId;
    if (id.isNotEmpty) context.push('/products/$id');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final post = widget.post;
    final bottomPad = MediaQuery.paddingOf(context).bottom + 12;
    final caption = post.caption.trim();
    final showMore = caption.length > 90 && !_captionExpanded;
    final shownCaption =
        showMore ? '${caption.substring(0, 90)}...more' : caption;
    final me = ref.watch(authStateProvider).valueOrNull;
    final sound = _video?.displaySound ?? 'Original sound - ${post.authorName}';

    return Stack(
      fit: StackFit.expand,
      children: [
        // Media + double-tap like
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTapDown: (d) => _burstAt = d.localPosition,
          onDoubleTap: () => _toggleLike(at: _burstAt),
          child: _isVideo
              ? _TimelineVideoSurface(
                  videoId: post.videoId!,
                  videoUrl: _video?.videoUrl ?? post.videoUrl,
                  mimeType: _video?.mimeType ?? 'video/mp4',
                  autoplay: widget.active,
                  mountPlayer: widget.active || widget.keepMedia,
                )
              : _ProductHero(
                  imageUrl: post.productImage,
                  name: post.productName,
                ),
        ),

        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 140,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 300,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.82),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Right action rail — like / comment / save / share / follow
        Positioned(
          right: 10,
          bottom: bottomPad + (_product != null ? 108 : 72),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AvatarFollow(
                imageUrl: post.authorImage,
                name: post.authorName,
                following: _following,
                isSelf: me?.id == post.authorId,
                onAvatar: _openAuthor,
                onFollow: _toggleFollow,
              ),
              const SizedBox(height: 18),
              _ActionBtn(
                icon: _liked ? Icons.favorite : Icons.favorite_border,
                color: _liked ? const Color(0xFFFF2D55) : Colors.white,
                label: _fmt(_likes),
                onTap: () => _toggleLike(),
              ),
              const SizedBox(height: 16),
              _ActionBtn(
                icon: Icons.chat_bubble,
                label: _fmt(_comments),
                onTap: _openComments,
              ),
              const SizedBox(height: 16),
              _ActionBtn(
                icon: _saved ? Icons.bookmark : Icons.bookmark_border,
                color: _saved ? const Color(0xFFFFC107) : Colors.white,
                label: _isVideo ? _fmt(_saves) : (_saved ? 'Saved' : 'Save'),
                onTap: _toggleSave,
              ),
              const SizedBox(height: 16),
              _ActionBtn(
                icon: Icons.reply_rounded,
                label: _isVideo ? _fmt(_shares) : 'Share',
                onTap: _shareMenu,
                flipX: true,
              ),
              if (_isVideo) ...[
                const SizedBox(height: 18),
                RotationTransition(
                  turns: _discCtrl,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 4),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2A2A2A), Color(0xFF111111)],
                      ),
                    ),
                    child: ClipOval(
                      child: (post.authorImage ?? '').isNotEmpty
                          ? HubsomImage(
                              url: post.authorImage!,
                              width: 46,
                              height: 46,
                              fit: BoxFit.cover,
                            )
                          : const Icon(
                              Icons.music_note,
                              color: Colors.white70,
                              size: 20,
                            ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Bottom meta + shop chip
        Positioned(
          left: 14,
          right: 86,
          bottom: bottomPad,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _openAuthor,
                child: Text(
                  post.authorName.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
                  ),
                ),
              ),
              if (caption.isNotEmpty) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () =>
                      setState(() => _captionExpanded = !_captionExpanded),
                  child: Text(
                    shownCaption,
                    style: const TextStyle(
                      color: Colors.white,
                      height: 1.25,
                      shadows: [Shadow(blurRadius: 6, color: Colors.black45)],
                    ),
                  ),
                ),
              ],
              if (_isVideo) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.music_note, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        sound,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (_product != null) ...[
                const SizedBox(height: 10),
                FeedProductShopStrip(
                  name: _product!.name,
                  priceGhs: _product!.effectivePrice,
                  imageUrl: _product!.images.isNotEmpty
                      ? _product!.images.first
                      : post.productImage,
                  inStock: _product!.stock > 0,
                  onView: _openProduct,
                  onBuy: _buyNow,
                ),
              ] else if (post.productId.isNotEmpty) ...[
                const SizedBox(height: 10),
                CommerceCtaBar(
                  compact: true,
                  overlay: true,
                  secondaryLabel: 'View',
                  primaryLabel: 'Buy now',
                  onSecondary: _openProduct,
                  onPrimary: _openProduct,
                ),
              ],
            ],
          ),
        ),

        AnimatedBuilder(
          animation: _heartBurst,
          builder: (_, __) {
            if (_heartBurst.isDismissed || _burstAt == null) {
              return const SizedBox.shrink();
            }
            final t = Curves.easeOut.transform(_heartBurst.value);
            return Positioned(
              left: _burstAt!.dx - 40,
              top: _burstAt!.dy - 40,
              child: Opacity(
                opacity: (1 - t).clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 0.6 + t * 1.1,
                  child: const Icon(
                    Icons.favorite,
                    color: Color(0xFFFF2D55),
                    size: 80,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _AvatarFollow extends StatelessWidget {
  const _AvatarFollow({
    required this.imageUrl,
    required this.name,
    required this.following,
    required this.isSelf,
    required this.onAvatar,
    required this.onFollow,
  });

  final String? imageUrl;
  final String name;
  final bool following;
  final bool isSelf;
  final VoidCallback onAvatar;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 64,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          GestureDetector(
            onTap: onAvatar,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: ClipOval(
                child: (imageUrl ?? '').isNotEmpty
                    ? HubsomImage(
                        url: imageUrl!,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                      )
                    : CircleAvatar(
                        backgroundColor: HubsomColors.forest,
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
              ),
            ),
          ),
          if (!isSelf && !following)
            Positioned(
              bottom: 0,
              child: GestureDetector(
                onTap: onFollow,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF2D55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 16),
                ),
              ),
            )
          else if (!isSelf && following)
            Positioned(
              bottom: 0,
              child: GestureDetector(
                onTap: onFollow,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2ECC71),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
    this.flipX = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool flipX;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(icon, color: color, size: 34, shadows: const [
      Shadow(blurRadius: 8, color: Colors.black54),
    ]);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Column(
        children: [
          flipX ? Transform.flip(flipX: true, child: iconWidget) : iconWidget,
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineVideoSurface extends StatefulWidget {
  const _TimelineVideoSurface({
    required this.videoId,
    required this.videoUrl,
    required this.mimeType,
    required this.autoplay,
    required this.mountPlayer,
  });

  final String videoId;
  final String? videoUrl;
  final String mimeType;
  final bool autoplay;
  final bool mountPlayer;

  @override
  State<_TimelineVideoSurface> createState() => _TimelineVideoSurfaceState();
}

class _TimelineVideoSurfaceState extends State<_TimelineVideoSurface> {
  bool _hydrated = false;
  bool _playerLocked = false;
  int _gen = 0;

  static String? _playableRemote(String? url) {
    final u = (url ?? '').trim();
    if (u.startsWith('http://') ||
        u.startsWith('https://') ||
        u.startsWith('blob:')) {
      return u;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    if (widget.mountPlayer) _playerLocked = true;
    _hydrate();
  }

  @override
  void didUpdateWidget(covariant _TimelineVideoSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mountPlayer) _playerLocked = true;
    if (oldWidget.videoId != widget.videoId) {
      _playerLocked = widget.mountPlayer;
      _hydrate();
      return;
    }
    // Only re-hydrate when we still lack media and a better URL arrived.
    if (!_hydrated && oldWidget.videoUrl != widget.videoUrl) {
      _hydrate();
    }
  }

  Future<void> _hydrate() async {
    final gen = ++_gen;

    final playable = _playableRemote(widget.videoUrl);
    if (playable != null) {
      if (mounted && gen == _gen) setState(() => _hydrated = true);
      return;
    }

    if (ProductDemoVideoStore.hasVideo(widget.videoId)) {
      if (mounted && gen == _gen) setState(() => _hydrated = true);
      return;
    }

    if (mounted) setState(() => _hydrated = false);

    await CloudVideoMedia.ensureLocalBytes(
      videoId: widget.videoId,
      videoUrl: widget.videoUrl,
      mimeType: widget.mimeType,
    );
    if (!mounted || gen != _gen) return;
    final after = await ProductDemoVideoStore.load(widget.videoId);
    if (!mounted || gen != _gen) return;
    setState(() => _hydrated = after != null);
  }

  @override
  Widget build(BuildContext context) {
    final showPlayer = _hydrated && (_playerLocked || widget.mountPlayer);

    // Always black — never flash a product still under a broken/loading video.
    if (!showPlayer) {
      return ColoredBox(
        color: Colors.black,
        child: widget.mountPlayer && !_hydrated
            ? const Center(
                child: CircularProgressIndicator(
                  color: Colors.white54,
                  strokeWidth: 2,
                ),
              )
            : null,
      );
    }

    return ProductDemoVideoPlayer(
      key: ValueKey('timeline-video-${widget.videoId}'),
      productId: widget.videoId,
      remoteUrl: _playableRemote(widget.videoUrl),
      expand: true,
      autoplay: widget.autoplay,
      borderRadius: 0,
      showPlayOverlay: false,
    );
  }
}

class _ProductHero extends StatelessWidget {
  const _ProductHero({required this.imageUrl, required this.name});
  final String? imageUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    if ((imageUrl ?? '').isNotEmpty) {
      return HubsomImage(
        url: imageUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [HubsomColors.forest, HubsomColors.blue],
        ),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      child: Text(
        name,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 28,
        ),
      ),
    );
  }
}
