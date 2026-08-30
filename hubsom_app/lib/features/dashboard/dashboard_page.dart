import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/hubsom_colors.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final cartCount = ref.watch(cartProvider).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Text('Dashboard', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(user == null ? 'Sign in for personalized activity.' : 'Welcome back, ${user.name}.'),
        const SizedBox(height: 16),
        Wrap(spacing: 10, runSpacing: 10, children: [
          _stat(context, 'Cart items', '$cartCount'),
          _stat(context, 'Saved', '${user?.savedProductIds.length ?? 0}'),
          _stat(context, 'Following', '${user?.followingSellerIds.length ?? 0}'),
          _stat(context, 'Wallet', 'GHS ${(user?.walletBalanceGhs ?? 0).toStringAsFixed(0)}'),
        ]),
        const SizedBox(height: 20),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.videocam, color: HubsomColors.live),
          title: const Text('Live shopping'),
          onTap: () => context.push('/live'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.gavel, color: HubsomColors.gold),
          title: const Text('Auctions'),
          onTap: () => context.push('/auctions'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.bolt, color: HubsomColors.orange),
          title: const Text('Flash sales'),
          onTap: () => context.push('/flash-sales'),
        ),
        if (user != null && (user.role == 'seller' || user.role == 'both'))
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.storefront, color: HubsomColors.forest),
            title: const Text('Seller hub'),
            onTap: () => context.push('/seller'),
          ),
        if (user != null && user.isHuber)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.two_wheeler, color: HubsomColors.huberNavy),
            title: const Text('Huber driver hub'),
            onTap: () => context.go('/huber'),
          ),
      ],
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HubsomColors.forest.withValues(alpha: 0.1)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}
