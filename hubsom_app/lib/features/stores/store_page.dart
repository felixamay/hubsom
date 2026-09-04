import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/require_auth.dart';
import '../../core/providers/core_providers.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../models/product.dart';
import '../../models/seller.dart';
import '../../widgets/hubsom_image.dart';
import '../../widgets/product_card.dart';

class StorePage extends ConsumerStatefulWidget {
  const StorePage({super.key, required this.slug});
  final String slug;

  @override
  ConsumerState<StorePage> createState() => _StorePageState();
}

class _StorePageState extends ConsumerState<StorePage> {
  Seller? _seller;
  bool _loading = true;
  bool _following = false;
  bool _followBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final seller =
        await ref.read(catalogRepositoryProvider).getSeller(widget.slug);
    if (!mounted) return;
    final following = seller != null &&
        ref.read(catalogRepositoryProvider).isFollowingSeller(seller.id);
    setState(() {
      _seller = seller;
      _following = following;
      _loading = false;
    });
  }

  Future<void> _toggleFollow() async {
    final seller = _seller;
    if (seller == null) return;
    if (!ensureSignedIn(context, ref, message: 'Sign in to follow this account')) {
      return;
    }
    setState(() => _followBusy = true);
    try {
      final catalog = ref.read(catalogRepositoryProvider);
      final next = _following
          ? await catalog.unfollowSeller(seller.id)
          : await catalog.followSeller(seller.id);
      ref.invalidate(authStateProvider);
      if (!mounted) return;
      setState(() => _following = next);
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final seller = _seller;
    if (seller == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Store not found')),
      );
    }
    final initial = seller.name.isNotEmpty
        ? seller.name.substring(0, 1).toUpperCase()
        : 'S';
    return Scaffold(
      appBar: AppBar(
        title: Text(seller.name),
        actions: [
          IconButton(
            tooltip: 'Message',
            onPressed: () {
              if (!ensureSignedIn(context, ref, message: 'Sign in to message')) {
                return;
              }
              final peerId = (seller.ownerUserId?.isNotEmpty == true)
                  ? seller.ownerUserId!
                  : seller.id;
              context.push('/messages/$peerId');
            },
            icon: const Icon(Icons.chat_bubble_outline),
          ),
          TextButton(
            onPressed: _followBusy ? null : _toggleFollow,
            child: Text(_following ? 'Following' : 'Follow account'),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: HubsomColors.forest,
                  child: seller.avatar.trim().isEmpty
                      ? Text(
                          initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      : ClipOval(
                          child: HubsomImage(
                            url: seller.avatar,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                            placeholder: Container(
                              width: 72,
                              height: 72,
                              color: HubsomColors.forest,
                              alignment: Alignment.center,
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        seller.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(seller.bio),
                      Text(
                        '${seller.city}, ${seller.region} · ★ ${seller.rating.toStringAsFixed(1)} · ${seller.followers} followers',
                      ),
                      const SizedBox(height: 10),
                      FilledButton.tonal(
                        onPressed: _followBusy ? null : _toggleFollow,
                        child: Text(
                          _following ? 'Following' : 'Follow account',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder(
              future: ref
                  .read(catalogRepositoryProvider)
                  .listProducts(sellerId: seller.id),
              builder: (context, pSnap) {
                final products = pSnap.data ?? <Product>[];
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.68,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: products.length,
                  itemBuilder: (_, i) => ProductCard(product: products[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
