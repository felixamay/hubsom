import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/core_providers.dart';
import '../../core/services/local_commerce_store.dart';
import '../../core/services/local_huber_store.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../core/utils/money.dart';
import '../../models/order.dart';
import '../../models/product.dart';
import '../../models/stream.dart';
import '../../models/user.dart';
import '../../widgets/product_card.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<Order> _purchases = const [];
  bool _loadingPurchases = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _tabs.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPurchases());
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadPurchases() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    setState(() => _loadingPurchases = true);
    try {
      final orders = await ref.read(orderRepositoryProvider).buyerOrders();
      if (!mounted) return;
      setState(() {
        _purchases = orders;
        _loadingPurchases = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingPurchases = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<HubsomUser?>>(authStateProvider, (prev, next) {
      final was = prev?.valueOrNull?.id;
      final now = next.valueOrNull?.id;
      if (now != null && now != was) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _loadPurchases();
        });
      }
    });
    final user = ref.watch(authStateProvider).valueOrNull;
    final cartCount = ref.watch(cartProvider).length;
    final catalog = ref.watch(catalogRepositoryProvider);
    final followingCount = user?.followingSellerIds.length ?? 0;
    final followerCount = catalog.myFollowerCount();
    final streams = ref.watch(streamsProvider).maybeWhen(
          data: (list) => list.whereType<LiveStream>().toList(),
          orElse: LocalCommerceStore.listStreams,
        );

    if (user == null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          Text(
            'Dashboard',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          const Text('Sign in for personalized activity.'),
          const SizedBox(height: 16),
          _stat(
            context,
            label: 'Cart items',
            value: '$cartCount',
            icon: Icons.shopping_bag_outlined,
            onTap: () => context.push('/cart'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.videocam, color: HubsomColors.live),
            title: const Text('Live shopping'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/live'),
          ),
        ],
      );
    }

    final bids = _bidsForUser(user, streams);
    final offers = _offersForUser(user, _purchases);

    final tabBar = TabBar(
      controller: _tabs,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      labelColor: HubsomColors.forest,
      indicatorColor: HubsomColors.forest,
      tabs: [
        Tab(text: 'Purchases (${_purchases.length})'),
        Tab(text: 'Bids (${bids.length})'),
        Tab(text: 'Offers (${offers.length})'),
        Tab(text: 'Saved (${user.savedProductIds.length})'),
      ],
    );

    return RefreshIndicator(
      onRefresh: _loadPurchases,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dashboard',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text('Welcome back, ${user.name}.'),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 96,
              child: ListView(
                key: const Key('dashboard-stats'),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                children: [
                  _stat(
                    context,
                    label: 'Purchases',
                    value: '${_purchases.length}',
                    icon: Icons.receipt_long_outlined,
                    onTap: () => _tabs.animateTo(0),
                  ),
                  _stat(
                    context,
                    label: 'Bids',
                    value: '${bids.length}',
                    icon: Icons.gavel,
                    onTap: () => _tabs.animateTo(1),
                  ),
                  _stat(
                    context,
                    label: 'Offers',
                    value: '${offers.length}',
                    icon: Icons.local_shipping_outlined,
                    onTap: () => _tabs.animateTo(2),
                  ),
                  _stat(
                    context,
                    label: 'Saved',
                    value: '${user.savedProductIds.length}',
                    icon: Icons.favorite_border,
                    onTap: () => _tabs.animateTo(3),
                  ),
                  _stat(
                    context,
                    label: 'Cart items',
                    value: '$cartCount',
                    icon: Icons.shopping_bag_outlined,
                    onTap: () => context.push('/cart'),
                  ),
                  _stat(
                    context,
                    label: 'Following',
                    value: '$followingCount',
                    icon: Icons.person_add_alt_1_outlined,
                    onTap: () => context.push('/account/following'),
                  ),
                  _stat(
                    context,
                    label: 'Followers',
                    value: '$followerCount',
                    icon: Icons.groups_outlined,
                    onTap: () => context.push('/account/followers'),
                  ),
                  _stat(
                    context,
                    label: 'Wallet',
                    value: 'GHS ${user.walletBalanceGhs.toStringAsFixed(0)}',
                    icon: Icons.account_balance_wallet_outlined,
                    onTap: () => context.push('/wallet'),
                  ),
                  _stat(
                    context,
                    label: 'Gift points',
                    value: '${user.giftPoints}',
                    icon: Icons.card_giftcard_outlined,
                    onTap: () => context.push('/gifts'),
                  ),
                ].expand((w) => [w, const SizedBox(width: 10)]).toList()
                  ..removeLast(),
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _PinnedTabBarDelegate(tabBar),
          ),
          ..._activitySlivers(
            bids: bids,
            offers: offers,
            user: user,
          ),
        ],
      ),
    );
  }

  List<Widget> _activitySlivers({
    required List<_BidRow> bids,
    required List<_OfferRow> offers,
    required HubsomUser user,
  }) {
    switch (_tabs.index) {
      case 1:
        return _BidsTab.slivers(bids);
      case 2:
        return _OffersTab.slivers(offers);
      case 3:
        return [
          _SavedSliver(user: user),
        ];
      default:
        return _PurchasesTab.slivers(
          loading: _loadingPurchases,
          orders: _purchases,
        );
    }
  }

  Widget _stat(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          width: 136,
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: HubsomColors.forest.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: HubsomColors.forest),
                  const Spacer(),
                  const Icon(Icons.chevron_right, size: 16, color: Colors.black38),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BidRow {
  const _BidRow({
    required this.streamId,
    required this.title,
    required this.productName,
    required this.amountGhs,
    required this.status,
    required this.winning,
  });

  final String streamId;
  final String title;
  final String productName;
  final double amountGhs;
  final String status;
  final bool winning;
}

class _OfferRow {
  const _OfferRow({
    required this.title,
    required this.subtitle,
    required this.status,
    this.feeGhs,
  });

  final String title;
  final String subtitle;
  final String status;
  final double? feeGhs;
}

List<_BidRow> _bidsForUser(HubsomUser user, List<LiveStream> streams) {
  final rows = <_BidRow>[];
  for (final stream in streams) {
    final auction = stream.auction;
    if (auction == null) continue;
    final mine = auction.recentBids
        .where(
          (b) =>
              b.bidderId == user.id ||
              b.bidderName.toLowerCase() == user.name.toLowerCase(),
        )
        .toList();
    if (mine.isEmpty) continue;
    mine.sort((a, b) => b.at.compareTo(a.at));
    final latest = mine.first;
    final product = LocalCommerceStore.getProduct(auction.productId);
    final winning = auction.highestBidderId == user.id ||
        auction.highestBidder == user.name;
    final status = auction.isSold
        ? (winning ? 'Won' : 'Ended')
        : auction.isOpen
            ? (winning ? 'Winning' : 'Outbid')
            : (winning ? 'Highest bid' : 'Ended');
    rows.add(
      _BidRow(
        streamId: stream.id,
        title: stream.title,
        productName: product?.name ?? 'Auction lot',
        amountGhs: latest.amountGhs,
        status: status,
        winning: winning,
      ),
    );
  }
  return rows;
}

List<_OfferRow> _offersForUser(HubsomUser user, List<Order> purchases) {
  final rows = <_OfferRow>[];
  final purchaseIds = purchases.map((o) => o.id).toSet();
  final shipments = LocalHuberStore.listShipments();
  final offers = LocalHuberStore.listOffers();

  for (final offer in offers) {
    final shipment = LocalHuberStore.getShipment(offer.shipmentId);
    final forBuyer = shipment != null &&
        shipment.orderIds.any(purchaseIds.contains);
    final forRider = user.isHuber &&
        (offer.huberId == user.huberId || offer.huberId == user.id);
    final forSeller = user.sellerId != null &&
        shipment?.sellerId == user.sellerId;
    if (!forBuyer && !forRider && !forSeller) continue;
    rows.add(
      _OfferRow(
        title: forRider
            ? 'Hail Rider offer · ${offer.sellerName}'
            : 'Delivery offer · ${offer.huberName}',
        subtitle: [
          if (offer.pickupCity.isNotEmpty) 'Pickup ${offer.pickupCity}',
          if (offer.dropoffCity.isNotEmpty) 'drop ${offer.dropoffCity}',
        ].join(' · '),
        status: offer.status,
        feeGhs: offer.offeredFeeGhs,
      ),
    );
  }

  for (final shipment in shipments) {
    final forBuyer = shipment.orderIds.any(purchaseIds.contains);
    final forSeller =
        user.sellerId != null && shipment.sellerId == user.sellerId;
    if (!forBuyer && !forSeller) continue;
    if (offers.any((o) => o.shipmentId == shipment.id)) continue;
    rows.add(
      _OfferRow(
        title: 'Shipment ${shipment.id}',
        subtitle: '${shipment.orderIds.length} order(s)',
        status: shipment.status,
      ),
    );
  }
  return rows;
}

class _PurchasesTab {
  static List<Widget> slivers({
    required bool loading,
    required List<Order> orders,
  }) {
    if (orders.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Text(loading ? 'Loading purchases…' : 'No purchases yet'),
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        sliver: SliverList.separated(
          itemCount: orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final order = orders[i];
            final name = order.lines.isEmpty
                ? 'Order ${order.id}'
                : order.lines.map((l) => l.name).join(', ');
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${formatGhs(order.subtotalGhs)} · ${_statusLabel(order.status)}',
                      style: const TextStyle(
                        color: HubsomColors.forest,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (order.deliveryEstimate.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        order.deliveryEstimate,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 12),
                    _ProgressTrack(status: order.status),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ];
  }
}

class _BidsTab {
  static List<Widget> slivers(List<_BidRow> bids) {
    if (bids.isEmpty) {
      return [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: Text('No bids yet')),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        sliver: SliverList.separated(
          itemCount: bids.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final bid = bids[i];
            return Card(
              child: ListTile(
                leading: Icon(
                  Icons.gavel,
                  color: bid.winning ? HubsomColors.gold : HubsomColors.forest,
                ),
                title: Text(bid.productName),
                subtitle: Text('${bid.title} · ${bid.status}'),
                trailing: Text(
                  formatGhs(bid.amountGhs),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                onTap: () => context.push('/live/${bid.streamId}'),
              ),
            );
          },
        ),
      ),
    ];
  }
}

class _OffersTab {
  static List<Widget> slivers(List<_OfferRow> offers) {
    if (offers.isEmpty) {
      return [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: Text('No delivery offers yet')),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        sliver: SliverList.separated(
          itemCount: offers.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final offer = offers[i];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (offer.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(offer.subtitle),
                    ],
                    if (offer.feeGhs != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        formatGhs(offer.feeGhs!),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: HubsomColors.forest,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _ProgressTrack(status: offer.status),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ];
  }
}

class _SavedSliver extends ConsumerStatefulWidget {
  const _SavedSliver({required this.user});

  final HubsomUser user;

  @override
  ConsumerState<_SavedSliver> createState() => _SavedSliverState();
}

class _SavedSliverState extends ConsumerState<_SavedSliver> {
  List<Product>? _products;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final catalog = ref.read(catalogRepositoryProvider);
    final found = <Product>[];
    for (final id in widget.user.savedProductIds) {
      final p = await catalog.getProduct(id);
      if (p != null) found.add(p);
    }
    if (mounted) setState(() => _products = found);
  }

  @override
  Widget build(BuildContext context) {
    final ids = widget.user.savedProductIds;
    if (ids.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: Text('No saved products')),
      );
    }
    if (_products == null) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: Text('Loading saved…')),
      );
    }
    if (_products!.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: Text('No saved products')),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.68,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, i) => ProductCard(product: _products![i]),
          childCount: _products!.length,
        ),
      ),
    );
  }
}

class _PinnedTabBarDelegate extends SliverPersistentHeaderDelegate {
  _PinnedTabBarDelegate(this.tabBar);

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      elevation: overlapsContent ? 1 : 0,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedTabBarDelegate oldDelegate) =>
      oldDelegate.tabBar != tabBar;
}

const _progressSteps = ['paid', 'processing', 'shipped', 'delivered'];

int _progressIndex(String status) {
  switch (status) {
    case 'pending_payment':
    case 'pending':
    case 'queued':
    case 'sent':
      return 0;
    case 'paid':
    case 'offering':
    case 'accepted':
      return 1;
    case 'processing':
    case 'assigned':
    case 'ready':
      return 2;
    case 'shipped':
    case 'out_for_delivery':
    case 'arrived_pickup':
    case 'arrived_dropoff':
      return 3;
    case 'delivered':
      return 4;
    default:
      final i = _progressSteps.indexOf(status);
      return i < 0 ? 0 : i + 1;
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'pending_payment':
    case 'pending':
      return 'Awaiting payment';
    case 'paid':
      return 'Paid';
    case 'processing':
      return 'Preparing';
    case 'shipped':
    case 'out_for_delivery':
      return 'On the way';
    case 'delivered':
      return 'Delivered';
    case 'cancelled':
      return 'Cancelled';
    case 'sent':
    case 'queued':
      return 'Offered';
    case 'accepted':
    case 'assigned':
      return 'Rider assigned';
    case 'offering':
      return 'Finding a rider';
    default:
      return status.replaceAll('_', ' ');
  }
}

class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    if (status == 'cancelled') {
      return const Text(
        'Cancelled',
        style: TextStyle(fontWeight: FontWeight.w800, color: Colors.redAccent),
      );
    }
    final done = _progressIndex(status).clamp(0, _progressSteps.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < _progressSteps.length; i++) ...[
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < done ? HubsomColors.forest : Colors.black12,
                ),
              ),
              if (i < _progressSteps.length - 1)
                Expanded(
                  child: Container(
                    height: 3,
                    color: i < done - 1 ? HubsomColors.forest : Colors.black12,
                  ),
                ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final step in _progressSteps)
              Expanded(
                child: Text(
                  step[0].toUpperCase() + step.substring(1),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: HubsomColors.ink.withValues(alpha: 0.7),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
