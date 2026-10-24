import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../core/utils/money.dart';
import '../../models/product.dart';
import '../../models/stream.dart';
import '../../widgets/hubsom_image.dart';

/// Browse live auctions and closed-but-unsold lots (products stay here, not in history).
class AuctionsPage extends ConsumerStatefulWidget {
  const AuctionsPage({super.key});

  @override
  ConsumerState<AuctionsPage> createState() => _AuctionsPageState();
}

class _AuctionsPageState extends ConsumerState<AuctionsPage> {
  Map<String, Product?> _products = {};
  String _loadedKey = '';

  Future<void> _loadProducts(List<LiveStream> streams) async {
    final ids = streams
        .map((s) => s.auction?.productId ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final key = ids.join('|');
    if (key == _loadedKey) return;
    _loadedKey = key;

    final catalog = ref.read(catalogRepositoryProvider);
    final next = <String, Product?>{};
    for (final id in ids) {
      next[id] = await catalog.getProduct(id);
    }
    if (!mounted) return;
    setState(() => _products = next);
  }

  @override
  Widget build(BuildContext context) {
    final streamsAsync = ref.watch(streamsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Auctions')),
      body: streamsAsync.when(
        data: (raw) {
          final streams = raw.cast<LiveStream>();
          final withAuction = streams
              .where((s) => s.auction != null && s.auction!.remainsOnAuctions)
              .toList();

          final live = withAuction
              .where((s) => s.auction!.isOpen || s.isLive)
              .toList();
          final available = withAuction
              .where((s) => !s.auction!.isOpen && !s.isLive)
              .toList();

          // Sold auctions are excluded — they become orders, not auction history.
          unawaited(_loadProducts([...live, ...available]));

          if (live.isEmpty && available.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.gavel, size: 48, color: HubsomColors.forest),
                    const SizedBox(height: 12),
                    Text(
                      'No auctions yet',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'When a live auction closes without a sale, the product stays here so shoppers can still find it.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => context.push('/seller/go-live'),
                      child: const Text('Go live & auction'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              _loadedKey = '';
              ref.invalidate(streamsProvider);
              await ref.read(streamsProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                if (live.isNotEmpty) ...[
                  Text(
                    'Live bidding',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Open now — join the show to place a bid.',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 10),
                  for (final s in live)
                    _AuctionTile(
                      stream: s,
                      product: _products[s.auction!.productId],
                      live: true,
                      onTap: () => context.push('/live/${s.id}'),
                    ),
                  const SizedBox(height: 22),
                ],
                if (available.isNotEmpty) ...[
                  Text(
                    'Available on Auctions',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Auction closed without a sale — products stay listed here, not in auction history.',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 10),
                  for (final s in available)
                    _AuctionTile(
                      stream: s,
                      product: _products[s.auction!.productId],
                      live: false,
                      onTap: () =>
                          context.push('/products/${s.auction!.productId}'),
                    ),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}

class _AuctionTile extends StatelessWidget {
  const _AuctionTile({
    required this.stream,
    required this.product,
    required this.live,
    required this.onTap,
  });

  final LiveStream stream;
  final Product? product;
  final bool live;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = stream.auction!;
    final image =
        product?.images.isNotEmpty == true ? product!.images.first : null;
    final title = product?.name ?? stream.title;
    final subtitle = live
        ? 'Current ${formatGhs(a.currentBidGhs)} · ${a.bidderCount} bidders'
        : a.status == 'reserve_not_met'
            ? 'Ask not met · last ${formatGhs(a.currentBidGhs)} · view product'
            : 'Closed · last ${formatGhs(a.currentBidGhs)} · still available';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: HubsomColors.forest.withValues(alpha: 0.12),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: HubsomImage(
                      url: image,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      placeholder: Container(
                        width: 72,
                        height: 72,
                        color: HubsomColors.mist,
                        child: const Icon(Icons.gavel),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: live
                                ? HubsomColors.live.withValues(alpha: 0.15)
                                : HubsomColors.mint,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            live ? 'LIVE AUCTION' : 'AVAILABLE',
                            style: TextStyle(
                              color: live
                                  ? HubsomColors.live
                                  : HubsomColors.forest,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    live ? Icons.videocam : Icons.chevron_right,
                    color: HubsomColors.forest,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
