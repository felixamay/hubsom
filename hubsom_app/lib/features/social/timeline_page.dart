import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../core/utils/money.dart';
import '../../models/product.dart';
import '../../models/product_social.dart';
import '../../widgets/hubsom_image.dart';
import '../../widgets/product_demo_video_player.dart';

/// Vertical, one-at-a-time timeline of posted products and shop videos.
class TimelinePage extends ConsumerStatefulWidget {
  const TimelinePage({super.key});

  @override
  ConsumerState<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends ConsumerState<TimelinePage> {
  List<TimelinePost> _posts = const [];
  bool _loading = true;
  String? _error;
  late final PageController _pageCtrl;
  int _index = 0;

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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final posts = await ref.read(catalogRepositoryProvider).listTimeline();
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _loading = false;
        _index = 0;
      });
      if (_pageCtrl.hasClients) {
        _pageCtrl.jumpToPage(0);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Timeline',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error != null
              ? Center(
                  child: Text(_error!, style: const TextStyle(color: Colors.white)),
                )
              : _posts.isEmpty
                  ? _EmptyTimeline(
                      onBrowse: () => context.go('/marketplace'),
                      onAddVideo: () => context.push('/videos/upload'),
                    )
                  : PageView.builder(
                      controller: _pageCtrl,
                      scrollDirection: Axis.vertical,
                      pageSnapping: true,
                      allowImplicitScrolling: false,
                      physics: const PageScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      itemCount: _posts.length,
                      onPageChanged: (i) => setState(() => _index = i),
                      itemBuilder: (_, i) => _TimelineSlide(
                        key: ValueKey(_posts[i].id),
                        post: _posts[i],
                        active: i == _index,
                      ),
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
  });

  final TimelinePost post;
  final bool active;

  @override
  ConsumerState<_TimelineSlide> createState() => _TimelineSlideState();
}

class _TimelineSlideState extends ConsumerState<_TimelineSlide> {
  Product? _product;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  @override
  void didUpdateWidget(covariant _TimelineSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      _loadProduct();
    }
  }

  Future<void> _loadProduct() async {
    final id = widget.post.productId;
    if (id.isEmpty) return;
    final p = await ref.read(catalogRepositoryProvider).getProduct(id);
    if (!mounted) return;
    setState(() => _product = p);
  }

  Future<void> _addToCart() async {
    final product = _product;
    if (product == null) {
      if (widget.post.productId.isNotEmpty) {
        context.push('/products/${widget.post.productId}');
      }
      return;
    }
    await ref.read(cartProvider.notifier).addProduct(product);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} added to cart'),
        action: SnackBarAction(
          label: 'View cart',
          onPressed: () => context.push('/cart'),
        ),
      ),
    );
  }

  void _openProduct() {
    final id = widget.post.productId;
    if (id.isNotEmpty) {
      context.push('/products/$id');
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final price = _product?.effectivePrice;
    final isVideo = post.isVideo && post.videoId != null;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Media: videos play inline on the timeline (no /videos navigation).
        if (isVideo) ...[
          _ProductHero(imageUrl: post.productImage, name: post.productName),
          if (widget.active)
            ProductDemoVideoPlayer(
              productId: post.videoId!,
              expand: true,
              autoplay: true,
              borderRadius: 0,
            )
          else
            const ColoredBox(color: Colors.black54),
        ] else
          _ProductHero(imageUrl: post.productImage, name: post.productName),

        // Gradients (ignore pointer so video tap-to-play still works)
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
          height: 280,
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

        // Meta + CTAs
        Positioned(
          left: 16,
          right: 16,
          bottom: bottom + 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: HubsomColors.forest,
                    child: (post.authorImage ?? '').isNotEmpty
                        ? ClipOval(
                            child: HubsomImage(
                              url: post.authorImage!,
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Text(
                            post.authorName.isNotEmpty
                                ? post.authorName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      post.authorName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      post.isVideo ? 'VIDEO' : 'PRODUCT',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              if (post.caption.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  post.caption,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, height: 1.3),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                post.productName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: HubsomColors.gold,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (price != null && price > 0) ...[
                const SizedBox(height: 2),
                Text(
                  formatGhs(price),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  if (post.productId.isNotEmpty)
                    Expanded(
                      child: FilledButton(
                        onPressed: _openProduct,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                        ),
                        child: const Text('View product'),
                      ),
                    ),
                  if (_product != null && _product!.stock > 0) ...[
                    if (post.productId.isNotEmpty) const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _addToCart,
                        style: FilledButton.styleFrom(
                          backgroundColor: HubsomColors.gold,
                          foregroundColor: Colors.black,
                        ),
                        child: const Text('Add to cart'),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              const Center(
                child: Text(
                  'Swipe up for next',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
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
