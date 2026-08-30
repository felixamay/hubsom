import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/hubsom_colors.dart';

class SellPage extends ConsumerWidget {
  const SellPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Text('Sell on Hubsom', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        const Text('List products, go live, run auctions, and dispatch Hubers — same seller workflows as web.'),
        const SizedBox(height: 20),
        if (user == null) ...[
          FilledButton(
            onPressed: () => context.push('/auth/sign-up?callbackUrl=%2Fsell'),
            child: const Text('Create seller account'),
          ),
          TextButton(
            onPressed: () => context.push('/auth/sign-in?callbackUrl=%2Fsell'),
            child: const Text('Sign in'),
          ),
        ] else if (user.role != 'seller' && user.role != 'both' && user.role != 'admin') ...[
          const Text('Your account is a buyer account. Create a seller (or buyer & seller) account to access seller tools.'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => context.push('/account/profile'),
            child: const Text('Manage account'),
          ),
        ] else ...[
          _tile(context, Icons.dashboard, 'Seller hub', '/seller'),
          _tile(context, Icons.inventory_2_outlined, 'My products', '/seller/products'),
          _tile(context, Icons.add_box_outlined, 'New product', '/seller/products/new'),
          _tile(context, Icons.movie_creation_outlined, 'Upload shop video', '/videos/upload'),
          _tile(context, Icons.play_circle_outline, 'Shop videos', '/videos'),
          _tile(context, Icons.videocam, 'Go live', '/seller/go-live'),
          _tile(context, Icons.local_shipping_outlined, 'Orders & shipments', '/seller/orders'),
          _tile(context, Icons.store, 'Store settings', '/seller/store'),
          _tile(context, Icons.insights, 'Analytics', '/seller/analytics'),
        ],
        const SizedBox(height: 24),
        if (user != null && (user.isHuber || user.role == 'admin'))
          _tile(context, Icons.two_wheeler, 'Huber driver hub', '/huber')
        else
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.two_wheeler_outlined, color: HubsomColors.huberNavy),
            title: const Text('Drive with Huber', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Same Hubsom sign-up — receive seller delivery offers'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              if (user == null) {
                context.push('/auth/sign-up?role=huber&callbackUrl=%2Fhuber');
                return;
              }
              await ref.read(authStateProvider.notifier).enableHuber();
              if (context.mounted) context.go('/huber/verify');
            },
          ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: HubsomColors.mint,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Text('Hubsom sellers can sell via buy-now, live shopping, auctions, flash sales, and store listings.'),
        ),
      ],
    );
  }

  Widget _tile(BuildContext context, IconData icon, String label, String path) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: HubsomColors.forest),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(path),
    );
  }
}
