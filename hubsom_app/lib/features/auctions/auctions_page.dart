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

/// Browse auctions that are live right now — ended lots are not listed.
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
    final signedIn = ref.watch(authStateProvider).valueOrNull != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Live auctions')),
      body: streamsAsync.when(
        data: (raw) {
          final live = raw
              .cast<LiveStream>()
              .where((s) => s.isLiveAuction)
              .toList();
          unawaited(_loadProducts(live));

          if (live.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.gavel, size: 48, color: HubsomColors.forest),
                    const SizedBox(height: 12),
                    Text(
                      'No live auctions right now',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'When a seller goes live with bidding, the auction shows here.',
                      textAlign: TextAlign.center,
                    ),
                    if (signedIn) ...[
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => context.push('/seller/go-live'),
                        child: const Text('Go live & auction'),
                      ),
                    ],
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
                    onTap: () => context.push('/live/${s.id}'),
                  ),
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
    required this.onTap,
  });

  final LiveStream stream;
  final Product? product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = stream.auction!;
    final image =
        product?.images.isNotEmpty == true ? product!.images.first : null;
    final title = product?.name ?? stream.title;

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
                            color: HubsomColors.live.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Text(
                            'LIVE AUCTION',
                            style: TextStyle(
                              color: HubsomColors.live,
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
                          'Current ${formatGhs(a.currentBidGhs)} · ${a.bidderCount} bidders',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.videocam, color: HubsomColors.forest),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
