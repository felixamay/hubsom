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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider((category: null, q: null)));
    final streamsAsync = ref.watch(streamsProvider);
    final promosAsync = ref.watch(promotionsProvider('landing'));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(productsProvider((category: null, q: null)));
        ref.invalidate(streamsProvider);
        ref.invalidate(promotionsProvider('landing'));
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hubsom',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: HubsomColors.forest,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Live commerce marketplace for Ghana — buy now, auctions, and live shopping.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: HubsomColors.ink.withValues(alpha: 0.7),
                        ),
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
                        onPressed: () => context.push('/auctions'),
                        child: const Text('Auctions'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  promosAsync.when(
                    data: (list) => PromoBanner(
                      promotions: list.cast<Promotion>(),
                    ),
                    loading: () => const SizedBox(height: 8),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: streamsAsync.when(
              data: (streams) {
                final live = streams.cast<LiveStream>().where((s) => s.isLive).toList();
                if (live.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Text('Live now', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                        const Spacer(),
                        TextButton(onPressed: () => context.push('/live'), child: const Text('See all')),
                      ],
                    ),
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
                                  colors: [HubsomColors.forest, HubsomColors.blue],
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    color: HubsomColors.live,
                                    child: const Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
                                  ),
                                  const Spacer(),
                                  Text(s.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                  Text('${s.viewerCount} watching', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
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
              loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 8),
              child: Row(
                children: [
                  Text('Buy now', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const Spacer(),
                  TextButton(onPressed: () => context.push('/marketplace'), child: const Text('Browse all')),
                ],
              ),
            ),
          ),
          productsAsync.when(
            data: (products) {
              final list = products.cast<Product>();
              final cross = ResponsiveScaffold.isWide(context)
                  ? 5
                  : ResponsiveScaffold.isTablet(context)
                      ? 3
                      : 2;
              return SliverPadding(
                padding: const EdgeInsets.only(bottom: 100),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cross,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.68,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => ProductCard(
                      product: list[i],
                      onSave: () => ref.read(catalogRepositoryProvider).toggleSave(list[i].id),
                    ),
                    childCount: list.length.clamp(0, 12),
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load catalog. Is the Hubsom API running at the configured base URL?\n$e'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
