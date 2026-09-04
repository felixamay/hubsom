import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/categories.dart';
import '../../core/providers/core_providers.dart';
import '../../core/services/product_demo_video_store.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../core/utils/money.dart';
import '../../models/product.dart';
import '../../models/promotion.dart';
import '../../models/seller.dart';
import '../../models/shop_video.dart';
import '../../models/stream.dart';
import '../../widgets/hubsom_image.dart';
import '../../widgets/product_card.dart';
import '../../widgets/product_demo_video_player.dart';
import '../../widgets/promo_banner.dart';
import '../../widgets/responsive_scaffold.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  static TextStyle _sectionTitle(BuildContext context) {
    final base = Theme.of(context).textTheme.titleMedium;
    return (base ?? const TextStyle()).copyWith(
      fontSize: (base?.fontSize ?? 16) + 3,
      fontWeight: FontWeight.w700,
      color: HubsomColors.ink,
      height: 1.25,
    );
  }

  static TextStyle _subheading(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyMedium;
    return (base ?? const TextStyle()).copyWith(
      fontSize: (base?.fontSize ?? 14) + 2,
      fontWeight: FontWeight.w600,
      color: HubsomColors.ink.withValues(alpha: 0.78),
      height: 1.35,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider((category: null, q: null)));
    final streamsAsync = ref.watch(streamsProvider);
    final promosAsync = ref.watch(promotionsProvider('landing'));
    final videosAsync = ref.watch(shopVideosProvider);
    final sellersAsync = ref.watch(sellersProvider);

    final products = productsAsync.when(
      data: (list) => list.whereType<Product>().toList(),
      loading: () => const <Product>[],
      error: (_, __) => const <Product>[],
    );

    final streams = streamsAsync.when(
      data: (list) => list.whereType<LiveStream>().toList(),
      loading: () => const <LiveStream>[],
      error: (_, __) => const <LiveStream>[],
    );

    final promos = promosAsync.when(
      data: (list) => list.whereType<Promotion>().toList(),
      loading: () => const <Promotion>[],
      error: (_, __) => const <Promotion>[],
    );

    final videos = videosAsync.when(
      data: (list) => list,
      loading: () => const <ShopVideo>[],
      error: (_, __) => const <ShopVideo>[],
    );

    final sellers = sellersAsync.when(
      data: (list) => list,
      loading: () => const <Seller>[],
      error: (_, __) => const <Seller>[],
    );

    final live = streams.where((s) => s.isLive).toList();
    final flash = products.where((p) => p.flashSale != null).toList();
    final auctions = streams
        .where((s) => s.auction != null && s.auction!.remainsOnAuctions)
        .toList();

    final cross = ResponsiveScaffold.isWide(context)
        ? 5
        : ResponsiveScaffold.isTablet(context)
            ? 3
            : 2;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(productsProvider((category: null, q: null)));
        ref.invalidate(streamsProvider);
        ref.invalidate(promotionsProvider('landing'));
        ref.invalidate(shopVideosProvider);
        ref.invalidate(sellersProvider);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 40, 0, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Live commerce for Ghana — shop now, catch auctions, and buy while shows are live.',
                    style: _subheading(context),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton(
                        onPressed: () => context.push('/marketplace'),
                        child: const Text('Shop marketplace'),
                      ),
                      OutlinedButton(
                        onPressed: () => context.push('/live'),
                        child: const Text('Watch live'),
                      ),
                      OutlinedButton(
                        onPressed: () => context.push('/sell'),
                        child: const Text('Sell on Hubsom'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Categories — real app taxonomy (not seeded products).
          SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'Categories',
              titleStyle: _sectionTitle(context),
              actionLabel: 'See all',
              onAction: () => context.push('/categories'),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: hubsomCategories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final c = hubsomCategories[i];
                  return InkWell(
                    onTap: () => context.push('/categories/${c.slug}'),
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 76,
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: HubsomColors.mint,
                            foregroundColor: HubsomColors.forest,
                            child: Icon(c.icon, size: 24),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            c.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              height: 1.15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Ads / promotions — only when API returns real promotions.
          if (promos.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'Ads',
                titleStyle: _sectionTitle(context),
              ),
            ),
            SliverToBoxAdapter(child: PromoBanner(promotions: promos)),
          ],

          // Live now
          if (live.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'Live now',
                titleStyle: _sectionTitle(context),
                actionLabel: 'See all',
                onAction: () => context.push('/live'),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 160,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: live.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    final s = live[i];
                    return InkWell(
                      onTap: () => context.push('/live/${s.id}'),
                      child: Container(
                        width: 220,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              HubsomColors.forest,
                              HubsomColors.blue,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              color: HubsomColors.live,
                              child: const Text(
                                'LIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              s.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${s.viewerCount} watching',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],

          // Flash sales — only products that actually have a flash sale.
          if (flash.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'Flash sales',
                titleStyle: _sectionTitle(context),
                actionLabel: 'See all',
                onAction: () => context.push('/flash-sales'),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 260,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: flash.length.clamp(0, 12),
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => SizedBox(
                    width: 168,
                    child: ProductCard(product: flash[i]),
                  ),
                ),
              ),
            ),
          ],

          // Auctions — only streams that still remain on auctions.
          if (auctions.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'Auctions',
                titleStyle: _sectionTitle(context),
                actionLabel: 'See all',
                onAction: () => context.push('/auctions'),
              ),
            ),
            ContainedAuctionStrip(streams: auctions),
          ],

          // Shop videos — at least 3 vertical columns with real thumbnails.
          if (videos.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'Shop videos',
                titleStyle: _sectionTitle(context),
                actionLabel: 'See all',
                onAction: () => context.push('/videos'),
              ),
            ),
            SliverGrid(
              gridDelegate: ContainedVideoGridDelegate.forContext(context),
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final v = videos[i];
                  Product? linked;
                  for (final id in v.productIds) {
                    final match = products.where((p) => p.id == id);
                    if (match.isNotEmpty) {
                      linked = match.first;
                      break;
                    }
                  }
                  return _HomeShopVideoCard(video: v, linkedProduct: linked);
                },
                childCount: videos.length.clamp(0, 12),
              ),
            ),
          ],

          // Stores — only real sellers.
          if (sellers.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'Stores',
                titleStyle: _sectionTitle(context),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 108,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: sellers.length.clamp(0, 16),
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) {
                    final s = sellers[i];
                    return InkWell(
                      onTap: () => context.push('/stores/${s.slug}'),
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 88,
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: HubsomColors.mint,
                              child: ClipOval(
                                child: HubsomImage(
                                  url: s.avatar,
                                  width: 60,
                                  height: 60,
                                  placeholder: const Icon(
                                    Icons.storefront_outlined,
                                    color: HubsomColors.forest,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              s.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                height: 1.15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],

          // Buy now
          ContainedBuyNow(
            products: products,
            crossAxisCount: cross,
            titleStyle: _sectionTitle(context),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.titleStyle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final TextStyle titleStyle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 32, bottom: 10),
      child: Row(
        children: [
          Text(title, style: titleStyle),
          const Spacer(),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

/// At least 3 vertical columns of portrait shop-video tiles.
class ContainedVideoGridDelegate {
  ContainedVideoGridDelegate._();

  static SliverGridDelegateWithFixedCrossAxisCount forContext(
    BuildContext context,
  ) {
    final cols = ResponsiveScaffold.isWide(context)
        ? 5
        : ResponsiveScaffold.isTablet(context)
            ? 4
            : 3;
    return ContainedVideoGridDelegate._delegate(cols);
  }

  static SliverGridDelegateWithFixedCrossAxisCount _delegate(int cols) {
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: cols,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 9 / 14,
    );
  }
}

/// Portrait shop-video card: real first frame as thumbnail, opens the feed.
class _HomeShopVideoCard extends StatefulWidget {
  const _HomeShopVideoCard({
    required this.video,
    this.linkedProduct,
  });

  final ShopVideo video;
  final Product? linkedProduct;

  @override
  State<_HomeShopVideoCard> createState() => _HomeShopVideoCardState();
}

class _HomeShopVideoCardState extends State<_HomeShopVideoCard> {
  late final Future<({Uint8List bytes, String mimeType})?> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = ProductDemoVideoStore.load(widget.video.id);
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    final linkedProduct = widget.linkedProduct;
    final caption = video.caption.trim();
    final cover =
        linkedProduct != null && linkedProduct.images.isNotEmpty
            ? linkedProduct.images.first
            : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/videos/${video.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.black,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (cover != null)
                  HubsomImage(
                    url: cover,
                    fit: BoxFit.cover,
                    placeholder: const ColoredBox(color: Colors.black),
                  )
                else
                  const ColoredBox(color: Colors.black),
                FutureBuilder(
                  future: _loadFuture,
                  builder: (context, snap) {
                    if (snap.data == null) {
                      return const SizedBox.shrink();
                    }
                    return AbsorbPointer(
                      child: ProductDemoVideoPlayer(
                        productId: video.id,
                        expand: true,
                        autoplay: false,
                        borderRadius: 0,
                        showPlayOverlay: false,
                      ),
                    );
                  },
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 72,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.78),
                        ],
                      ),
                    ),
                  ),
                ),
                const Center(
                  child: Icon(
                    Icons.play_circle_fill,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (caption.isNotEmpty)
                        Text(
                          caption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            height: 1.2,
                          ),
                        ),
                      if (caption.isNotEmpty) const SizedBox(height: 2),
                      Text(
                        video.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ContainedAuctionStrip extends StatelessWidget {
  const ContainedAuctionStrip({super.key, required this.streams});

  final List<LiveStream> streams;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 132,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: streams.length.clamp(0, 12),
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final s = streams[i];
            final a = s.auction!;
            final open = a.isOpen || s.isLive;
            return InkWell(
              onTap: () => open
                  ? context.push('/live/${s.id}')
                  : context.push('/products/${a.productId}'),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 210,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: HubsomColors.forest.withValues(alpha: 0.18),
                  ),
                  borderRadius: BorderRadius.circular(14),
                  color: HubsomColors.mist,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.gavel,
                          size: 16,
                          color: open ? HubsomColors.live : HubsomColors.forest,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          open ? 'Bidding open' : 'Available',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color:
                                open ? HubsomColors.live : HubsomColors.forest,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      s.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Current ${formatGhs(a.currentBidGhs)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: HubsomColors.ink.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class ContainedBuyNow extends StatelessWidget {
  const ContainedBuyNow({
    super.key,
    required this.products,
    required this.crossAxisCount,
    required this.titleStyle,
  });

  final List<Product> products;
  final int crossAxisCount;
  final TextStyle titleStyle;

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: _SectionHeader(
            title: 'Buy now',
            titleStyle: titleStyle,
            actionLabel: 'Browse all',
            onAction: () => context.push('/marketplace'),
          ),
        ),
        if (products.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
              child: Text(
                'No products yet. Sellers can publish from Sell → New product, then go live.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 100),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 14,
                crossAxisSpacing: 12,
                childAspectRatio: 0.74,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, i) => ProductCard(product: products[i]),
                childCount: products.length.clamp(0, 12),
              ),
            ),
          ),
      ],
    );
  }
}
