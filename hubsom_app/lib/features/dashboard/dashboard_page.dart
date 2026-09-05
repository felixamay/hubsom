import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/require_auth.dart';
import '../../core/providers/core_providers.dart';
import '../../core/theme/hubsom_colors.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final cartCount = ref.watch(cartProvider).length;
    final catalog = ref.watch(catalogRepositoryProvider);
    final followingCount = user?.followingSellerIds.length ?? 0;
    final followerCount = catalog.myFollowerCount();
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
        Text(
          user == null
              ? 'Sign in for personalized activity.'
              : 'Welcome back, ${user.name}.',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _stat(
              context,
              label: 'Cart items',
              value: '$cartCount',
              icon: Icons.shopping_bag_outlined,
              onTap: () => context.push('/cart'),
            ),
            _stat(
              context,
              label: 'Saved',
              value: '${user?.savedProductIds.length ?? 0}',
              icon: Icons.favorite_border,
              onTap: () {
                if (!ensureSignedIn(
                  context,
                  ref,
                  message: 'Sign in to see saved products',
                )) {
                  return;
                }
                context.push('/account/saved');
              },
            ),
            _stat(
              context,
              label: 'Following',
              value: '$followingCount',
              icon: Icons.person_add_alt_1_outlined,
              onTap: () {
                if (!ensureSignedIn(
                  context,
                  ref,
                  message: 'Sign in to see accounts you follow',
                )) {
                  return;
                }
                context.push('/account/following');
              },
            ),
            _stat(
              context,
              label: 'Followers',
              value: '$followerCount',
              icon: Icons.groups_outlined,
              onTap: () {
                if (!ensureSignedIn(
                  context,
                  ref,
                  message: 'Sign in to see your followers',
                )) {
                  return;
                }
                context.push('/account/followers');
              },
            ),
            _stat(
              context,
              label: 'Wallet',
              value: 'GHS ${(user?.walletBalanceGhs ?? 0).toStringAsFixed(0)}',
              icon: Icons.account_balance_wallet_outlined,
              onTap: () {
                if (!ensureSignedIn(
                  context,
                  ref,
                  message: 'Sign in to open your wallet',
                )) {
                  return;
                }
                context.push('/wallet');
              },
            ),
            _stat(
              context,
              label: 'Gift points',
              value: '${user?.giftPoints ?? 0}',
              icon: Icons.card_giftcard_outlined,
              onTap: () {
                if (!ensureSignedIn(
                  context,
                  ref,
                  message: 'Sign in to buy gift points',
                )) {
                  return;
                }
                context.push('/gifts');
              },
            ),
          ],
        ),
        const SizedBox(height: 20),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.card_giftcard, color: HubsomColors.gold),
          title: const Text('Buy gift points'),
          subtitle: const Text('Send roses, crowns, and more during live'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            if (!ensureSignedIn(
              context,
              ref,
              message: 'Sign in to buy gift points',
            )) {
              return;
            }
            context.push('/gifts');
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.videocam, color: HubsomColors.live),
          title: const Text('Live shopping'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/live'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.gavel, color: HubsomColors.gold),
          title: const Text('Auctions'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/auctions'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.bolt, color: HubsomColors.orange),
          title: const Text('Flash sales'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/flash-sales'),
        ),
        if (user != null && (user.role == 'seller' || user.role == 'both'))
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.storefront, color: HubsomColors.forest),
            title: const Text('Seller hub'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/seller'),
          ),
        if (user != null && user.isHuber)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading:
                const Icon(Icons.two_wheeler, color: HubsomColors.huberNavy),
            title: const Text('Huber driver hub'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/huber'),
          ),
      ],
    );
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
          width: 150,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: HubsomColors.forest.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: HubsomColors.forest),
                  const Spacer(),
                  const Icon(Icons.chevron_right, size: 18, color: Colors.black38),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
