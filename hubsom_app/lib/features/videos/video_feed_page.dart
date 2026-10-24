import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../core/utils/money.dart';
import '../../models/product.dart';
import '../../models/shop_video.dart';
import '../../widgets/hubsom_image.dart';
import '../../widgets/product_demo_video_player.dart';

/// Browse independent shop videos (TikTok-style) with product page links.
class VideoFeedPage extends ConsumerStatefulWidget {
  const VideoFeedPage({super.key, this.initialVideoId});
  final String? initialVideoId;

  @override
  ConsumerState<VideoFeedPage> createState() => _VideoFeedPageState();
}

class _VideoFeedPageState extends ConsumerState<VideoFeedPage> {
  List<ShopVideo> _videos = const [];
  bool _loading = true;
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
    setState(() => _loading = true);
    final videos = await ref.read(catalogRepositoryProvider).listShopVideos();
    if (!mounted) return;
    var start = 0;
    final initial = widget.initialVideoId;
    if (initial != null) {
      final i = videos.indexWhere((v) => v.id == initial);
      if (i >= 0) start = i;
    }
    setState(() {
      _videos = videos;
      _loading = false;
      _index = start;
    });
    if (start > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageCtrl.hasClients) {
          _pageCtrl.jumpToPage(start);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Videos'),
        actions: [
          TextButton(
            onPressed: () => context.push('/videos/upload'),
            child: const Text('Add video', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _videos.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.videocam_outlined,
                            color: Colors.white70, size: 48),
                        const SizedBox(height: 12),
                        const Text(
                          'No shop videos yet',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Upload a short clip and link products — watchers open the product page from the video.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => context.push('/videos/upload'),
                          child: const Text('Add video'),
                        ),
                      ],
                    ),
                  ),
                )
              : PageView.builder(
                  controller: _pageCtrl,
                  scrollDirection: Axis.vertical,
                  itemCount: _videos.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) => _VideoSlide(
                    video: _videos[i],
                    active: i == _index,
                  ),
                ),
    );
  }
}

class _VideoSlide extends ConsumerStatefulWidget {
  const _VideoSlide({required this.video, required this.active});
  final ShopVideo video;
  final bool active;

  @override
  ConsumerState<_VideoSlide> createState() => _VideoSlideState();
}

class _VideoSlideState extends ConsumerState<_VideoSlide> {
  List<Product> _products = const [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final catalog = ref.read(catalogRepositoryProvider);
    final loaded = <Product>[];
    for (final id in widget.video.productIds) {
      final p = await catalog.getProduct(id);
      if (p != null) loaded.add(p);
    }
    if (!mounted) return;
    setState(() => _products = loaded);
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.active)
          ProductDemoVideoPlayer(
            productId: video.id,
            expand: true,
            autoplay: true,
            borderRadius: 0,
          )
        else
          const ColoredBox(color: Colors.black),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.85),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '@${video.authorName}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (video.caption.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    video.caption,
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
                const SizedBox(height: 12),
                if (_products.isEmpty)
                  const Text(
                    'Products on this video',
                    style: TextStyle(color: Colors.white70),
                  )
                else
                  SizedBox(
                    height: 72,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _products.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) {
                        final p = _products[i];
                        final thumb =
                            p.images.isNotEmpty ? p.images.first : '';
                        return InkWell(
                          onTap: () => context.push('/products/${p.id}'),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 220,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: HubsomColors.gold.withValues(alpha: 0.7),
                              ),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: thumb.isEmpty
                                      ? Container(
                                          width: 52,
                                          height: 52,
                                          color: HubsomColors.forest,
                                          child: const Icon(
                                            Icons.shopping_bag,
                                            color: Colors.white,
                                          ),
                                        )
                                      : HubsomImage(
                                          url: thumb,
                                          width: 52,
                                          height: 52,
                                          fit: BoxFit.cover,
                                        ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        p.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        formatGhs(p.effectivePrice),
                                        style: const TextStyle(
                                          color: HubsomColors.gold,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const Text(
                                        'Open product',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
