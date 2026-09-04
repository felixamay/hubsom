import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/auth/require_auth.dart';
import '../../core/providers/core_providers.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../models/product.dart';
import '../../models/shop_video.dart';
import '../../widgets/commerce_cta_bar.dart';
import '../../widgets/hubsom_image.dart';
import '../../widgets/product_demo_video_player.dart';

/// Browse shop videos with TikTok-style overlays (actions + caption + sound).
class VideoFeedPage extends ConsumerStatefulWidget {
  const VideoFeedPage({super.key, this.initialVideoId});
  final String? initialVideoId;

  @override
  ConsumerState<VideoFeedPage> createState() => _VideoFeedPageState();
}

enum _FeedTab { following, shop, forYou }

class _VideoFeedPageState extends ConsumerState<VideoFeedPage> {
  List<ShopVideo> _all = const [];
  List<ShopVideo> _videos = const [];
  bool _loading = true;
  late final PageController _pageCtrl;
  int _index = 0;
  _FeedTab _tab = _FeedTab.forYou;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _load();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final catalog = ref.read(catalogRepositoryProvider);
    final videos = await catalog.listShopVideos();
    if (!mounted) return;
    setState(() {
      _all = videos;
      _loading = false;
    });
    _applyTab(jumpToInitial: true);
  }

  void _applyTab({bool jumpToInitial = false}) {
    final catalog = ref.read(catalogRepositoryProvider);
    List<ShopVideo> filtered;
    switch (_tab) {
      case _FeedTab.following:
        filtered = _all
            .where((v) {
              final sellerId = v.authorSellerId ?? '';
              return sellerId.isNotEmpty && catalog.isFollowingSeller(sellerId);
            })
            .toList();
      case _FeedTab.shop:
      case _FeedTab.forYou:
        filtered = List<ShopVideo>.from(_all);
    }
    var start = 0;
    final initial = widget.initialVideoId;
    if (jumpToInitial && initial != null) {
      final i = filtered.indexWhere((v) => v.id == initial);
      if (i >= 0) start = i;
    }
    setState(() {
      _videos = filtered;
      _index = start.clamp(0, filtered.isEmpty ? 0 : filtered.length - 1);
    });
    if (filtered.isNotEmpty && start > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageCtrl.hasClients) {
          _pageCtrl.jumpToPage(start);
        }
      });
    } else if (_pageCtrl.hasClients && filtered.isNotEmpty) {
      _pageCtrl.jumpToPage(0);
    }
  }

  void _selectTab(_FeedTab tab) {
    if (_tab == tab) return;
    setState(() => _tab = tab);
    _applyTab();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_loading)
            const Center(child: CircularProgressIndicator(color: Colors.white))
          else if (_videos.isEmpty)
            _EmptyFeed(
              tab: _tab,
              onAdd: () => context.push('/videos/upload'),
              onBrowse: () {
                _selectTab(_FeedTab.forYou);
              },
            )
          else
            PageView.builder(
              controller: _pageCtrl,
              scrollDirection: Axis.vertical,
              itemCount: _videos.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => _VideoSlide(
                key: ValueKey(_videos[i].id),
                video: _videos[i],
                active: i == _index,
                onChanged: (v) {
                  setState(() {
                    _videos = [
                      for (final x in _videos) if (x.id == v.id) v else x,
                    ];
                    _all = [
                      for (final x in _all) if (x.id == v.id) v else x,
                    ];
                  });
                },
              ),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _TopChrome(
              tab: _tab,
              onTab: _selectTab,
              onSearch: () => context.push('/marketplace'),
              onLive: () => context.push('/live'),
              onUpload: () => context.push('/videos/upload'),
            ),
          ),
          // Keep bottom safe area clear of system UI overlap on product strip.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: bottomInset,
            child: const ColoredBox(color: Colors.transparent),
          ),
        ],
      ),
    );
  }
}

class _TopChrome extends StatelessWidget {
  const _TopChrome({
    required this.tab,
    required this.onTab,
    required this.onSearch,
    required this.onLive,
    required this.onUpload,
  });

  final _FeedTab tab;
  final ValueChanged<_FeedTab> onTab;
  final VoidCallback onSearch;
  final VoidCallback onLive;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(8, top + 6, 8, 10),
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
      child: Row(
        children: [
          IconButton(
            onPressed: onLive,
            tooltip: 'LIVE',
            icon: const Icon(Icons.live_tv_rounded, color: Colors.white),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _TabLabel(
                  label: 'Following',
                  selected: tab == _FeedTab.following,
                  onTap: () => onTab(_FeedTab.following),
                ),
                const SizedBox(width: 16),
                _TabLabel(
                  label: 'Shop',
                  selected: tab == _FeedTab.shop,
                  onTap: () => onTab(_FeedTab.shop),
                ),
                const SizedBox(width: 16),
                _TabLabel(
                  label: 'For You',
                  selected: tab == _FeedTab.forYou,
                  onTap: () => onTab(_FeedTab.forYou),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onUpload,
            tooltip: 'Add video',
            icon: const Icon(Icons.add_box_outlined, color: Colors.white),
          ),
          IconButton(
            onPressed: onSearch,
            tooltip: 'Search',
            icon: const Icon(Icons.search, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              fontSize: 16,
              shadows: const [
                Shadow(blurRadius: 8, color: Colors.black54),
              ],
            ),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 3,
            width: selected ? 28 : 0,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed({
    required this.tab,
    required this.onAdd,
    required this.onBrowse,
  });
  final _FeedTab tab;
  final VoidCallback onAdd;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final following = tab == _FeedTab.following;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              following ? Icons.people_outline : Icons.videocam_outlined,
              color: Colors.white70,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              following ? 'No videos from people you follow' : 'No shop videos yet',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              following
                  ? 'Follow creators, then their shop videos show up here.'
                  : 'Upload a short clip and link products — watchers can like, comment, save, and shop.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            if (following)
              OutlinedButton(
                onPressed: onBrowse,
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('Browse For You'),
              )
            else
              FilledButton(
                onPressed: onAdd,
                child: const Text('Add video'),
              ),
          ],
        ),
      ),
    );
  }
}

class _VideoSlide extends ConsumerStatefulWidget {
  const _VideoSlide({
    super.key,
    required this.video,
    required this.active,
    required this.onChanged,
  });
  final ShopVideo video;
  final bool active;
  final ValueChanged<ShopVideo> onChanged;

  @override
  ConsumerState<_VideoSlide> createState() => _VideoSlideState();
}

class _VideoSlideState extends ConsumerState<_VideoSlide>
    with TickerProviderStateMixin {
  List<Product> _products = const [];
  late ShopVideo _video;
  bool _liked = false;
  bool _saved = false;
  bool _following = false;
  int _likes = 0;
  int _comments = 0;
  int _saves = 0;
  bool _captionExpanded = false;
  late final AnimationController _discCtrl;
  late final AnimationController _heartBurst;
  Offset? _burstAt;

  @override
  void initState() {
    super.initState();
    _video = widget.video;
    _discCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    _heartBurst = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    if (widget.active) _discCtrl.repeat();
    _syncSocial();
    _loadProducts();
  }

  @override
  void didUpdateWidget(covariant _VideoSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.id != widget.video.id) {
      _video = widget.video;
      _syncSocial();
      _loadProducts();
    } else if (oldWidget.video != widget.video) {
      _video = widget.video;
    }
    if (widget.active && !_discCtrl.isAnimating) {
      _discCtrl.repeat();
    } else if (!widget.active && _discCtrl.isAnimating) {
      _discCtrl.stop();
    }
  }

  @override
  void dispose() {
    _discCtrl.dispose();
    _heartBurst.dispose();
    super.dispose();
  }

  void _syncSocial() {
    final catalog = ref.read(catalogRepositoryProvider);
    final sellerId = _video.authorSellerId ?? '';
    setState(() {
      _liked = catalog.isVideoLiked(_video.id);
      _saved = catalog.isVideoSaved(_video.id);
      _following =
          sellerId.isNotEmpty && catalog.isFollowingSeller(sellerId);
      _likes = catalog.videoLikeCount(_video.id);
      _comments = catalog.videoCommentCount(_video.id);
      _saves = catalog.videoSaveCount(_video.id);
    });
  }

  Future<void> _loadProducts() async {
    final catalog = ref.read(catalogRepositoryProvider);
    final loaded = <Product>[];
    for (final id in _video.productIds) {
      final p = await catalog.getProduct(id);
      if (p != null) loaded.add(p);
    }
    if (!mounted) return;
    setState(() => _products = loaded);
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}K';
    return '$n';
  }

  Future<void> _toggleLike({Offset? at}) async {
    if (!ensureSignedIn(context, ref, message: 'Sign in to like')) return;
    final liked =
        await ref.read(catalogRepositoryProvider).toggleVideoLike(_video.id);
    if (!mounted) return;
    setState(() {
      _liked = liked;
      _likes = ref.read(catalogRepositoryProvider).videoLikeCount(_video.id);
    });
    if (liked) {
      _burstAt = at ?? Offset(
        MediaQuery.sizeOf(context).width * 0.5,
        MediaQuery.sizeOf(context).height * 0.42,
      );
      _heartBurst
        ..reset()
        ..forward();
    }
  }

  Future<void> _toggleSave() async {
    if (!ensureSignedIn(context, ref, message: 'Sign in to save')) return;
    final saved =
        await ref.read(catalogRepositoryProvider).toggleVideoSave(_video.id);
    if (!mounted) return;
    setState(() {
      _saved = saved;
      _saves = ref.read(catalogRepositoryProvider).videoSaveCount(_video.id);
    });
  }

  Future<void> _toggleFollow() async {
    final sellerId = _video.authorSellerId;
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
    await context.push('/videos/${_video.id}/comments');
    if (!mounted) return;
    setState(() {
      _comments =
          ref.read(catalogRepositoryProvider).videoCommentCount(_video.id);
    });
  }

  Future<void> _share() async {
    final catalog = ref.read(catalogRepositoryProvider);
    final text =
        'Watch ${_video.authorName} on Hubsom: https://hubsom.com/videos/${_video.id}';
    await Share.share(text, subject: _video.authorName);
    final count = await catalog.recordVideoShare(_video.id);
    if (!mounted) return;
    final updated = _video.copyWith(shareCount: count);
    setState(() => _video = updated);
    widget.onChanged(updated);
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
            ListTile(
              leading: const Icon(Icons.dynamic_feed, color: Colors.white),
              title: const Text('Post to timeline',
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, 'timeline'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'link') {
      await _share();
      return;
    }
    await ref.read(catalogRepositoryProvider).shareVideoToTimeline(_video.id);
    final fresh = await ref.read(catalogRepositoryProvider).getShopVideo(_video.id);
    if (!mounted) return;
    if (fresh != null) {
      setState(() => _video = fresh);
      widget.onChanged(fresh);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Shared to your timeline')),
    );
  }

  void _openAuthor() {
    final sellerId = _video.authorSellerId;
    if (sellerId == null || sellerId.isEmpty) return;
    context.push('/stores/$sellerId');
  }

  Future<void> _buyProduct(Product product) async {
    if (!ensureSignedIn(context, ref, message: 'Sign in to buy')) return;
    await ref.read(cartProvider.notifier).addProduct(product, source: 'buy-now');
    if (!mounted) return;
    context.push('/checkout');
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom + 12;
    final caption = _video.caption.trim();
    final showMore = caption.length > 90 && !_captionExpanded;
    final shownCaption = showMore ? '${caption.substring(0, 90)}...more' : caption;

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onDoubleTapDown: (d) => _burstAt = d.localPosition,
          onDoubleTap: () => _toggleLike(at: _burstAt),
          child: widget.active
              ? ProductDemoVideoPlayer(
                  productId: _video.id,
                  remoteUrl: _video.videoUrl,
                  expand: true,
                  autoplay: true,
                  borderRadius: 0,
                )
              : const ColoredBox(color: Colors.black),
        ),
        // Bottom fade
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 280,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.75),
                ],
              ),
            ),
          ),
        ),
        // Right action rail
        Positioned(
          right: 10,
          bottom: bottomPad + (_products.isNotEmpty ? 108 : 88),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AvatarFollow(
                imageUrl: _video.authorImage,
                name: _video.authorName,
                following: _following,
                isSelf: ref.watch(authStateProvider).valueOrNull?.id ==
                    _video.authorId,
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
                label: _fmt(_saves),
                onTap: _toggleSave,
              ),
              const SizedBox(height: 16),
              _ActionBtn(
                icon: Icons.reply_rounded,
                label: _fmt(_video.shareCount),
                onTap: _shareMenu,
                flipX: true,
              ),
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
                    child: (_video.authorImage ?? '').isNotEmpty
                        ? HubsomImage(
                            url: _video.authorImage!,
                            width: 46,
                            height: 46,
                            fit: BoxFit.cover,
                          )
                        : const Icon(Icons.music_note,
                            color: Colors.white70, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Bottom meta
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
                  _video.authorName.toUpperCase(),
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
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.music_note, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _MarqueeText(text: _video.displaySound),
                  ),
                ],
              ),
              if (_products.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 96,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _products.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) {
                      final p = _products[i];
                      return SizedBox(
                        width: 248,
                        child: FeedProductShopStrip(
                          name: p.name,
                          priceGhs: p.effectivePrice,
                          imageUrl:
                              p.images.isNotEmpty ? p.images.first : null,
                          inStock: p.stock > 0,
                          onView: () => context.push('/products/${p.id}'),
                          onBuy: () => _buyProduct(p),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        // Double-tap heart burst
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

class _MarqueeText extends StatefulWidget {
  const _MarqueeText({required this.text});
  final String text;

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox(
        height: 18,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            return FractionalTranslation(
              translation: Offset(1 - _ctrl.value * 2, 0),
              child: Text(
                widget.text,
                maxLines: 1,
                softWrap: false,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
