import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../models/product.dart';
import '../../models/promotion.dart';
import '../../models/stream.dart';
import '../../widgets/product_card.dart';
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
                        onPressed: () => context.push('/videos'),
                        child: const Text('Shop videos'),
                      ),
                      OutlinedButton(
                        onPressed: () => context.push('/videos/upload'),
                        child: const Text('Add video'),
                      ),
                      OutlinedButton(
                        onPressed: () => context.push('/auctions'),
                        child: const Text('Auctions'),
                      ),
                      OutlinedButton(
                        onPressed: () => context.push('/huber'),
                        child: const Text('Hail riders'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  PromoBanner(promotions: promos),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Builder(
              builder: (context) {
                final live = streams.where((s) => s.isLive).toList();
                if (live.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Text('Live now', style: _sectionTitle(context)),
                        const Spacer(),
                        TextButton(
                          onPressed: () => context.push('/live'),
                          child: const Text('See all'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
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
                  ],
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 36, bottom: 8),
              child: Row(
                children: [
                  Text('Buy now', style: _sectionTitle(context)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => context.push('/marketplace'),
                    child: const Text('Browse all'),
                  ),
                ],
              ),
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
                  crossAxisCount: cross,
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
      ),
    );
  }
}
