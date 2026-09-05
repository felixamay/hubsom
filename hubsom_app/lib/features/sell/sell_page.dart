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
    final isSeller = user != null &&
        (user.role == 'seller' || user.role == 'both' || user.role == 'admin');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Text(
          'Sell on Hubsom',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        const Text(
          'Products and videos are separate. List items to sell, or add a short video that links to those products.',
        ),
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
        ] else ...[
          _sectionTitle(context, 'Products'),
          const Text(
            'Create and manage real listings with photos, price, and quantity.',
          ),
          const SizedBox(height: 8),
          if (isSeller) ...[
            _tile(
              context,
              Icons.add_box_outlined,
              'Add product',
              '/seller/products/new',
            ),
            _tile(
              context,
              Icons.inventory_2_outlined,
              'My products',
              '/seller/products',
            ),
            _tile(context, Icons.dashboard, 'Seller hub', '/seller'),
            _tile(context, Icons.videocam, 'Go live', '/seller/go-live'),
            _tile(
              context,
              Icons.local_shipping_outlined,
              'Orders & shipments',
              '/seller/orders',
            ),
            _tile(context, Icons.store, 'Store settings', '/seller/store'),
            _tile(context, Icons.insights, 'Analytics', '/seller/analytics'),
          ] else ...[
            const Text(
              'Your account is a buyer account. Create a seller (or buyer & seller) account to list products.',
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.push('/account/profile'),
              child: const Text('Manage account'),
            ),
          ],
          const SizedBox(height: 24),
          _sectionTitle(context, 'Videos'),
          const Text(
            'Add a video on its own — not a product listing. Link products so watchers open the product page.',
          ),
          const SizedBox(height: 8),
          _tile(
            context,
            Icons.movie_creation_outlined,
            'Add video',
            '/videos/upload',
          ),
          _tile(
            context,
            Icons.play_circle_outline,
            'Watch videos',
            '/videos',
          ),
        ],
        const SizedBox(height: 24),
        if (user != null && (user.isHuber || user.role == 'admin'))
          _tile(context, Icons.two_wheeler, 'Hail Rider hub', '/huber')
        else
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.two_wheeler_outlined,
              color: HubsomColors.huberNavy,
            ),
            title: const Text(
              'Drive as a Hail Rider',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'Same Hubsom sign-up — receive seller delivery offers',
            ),
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
          child: const Text(
            'Tip: Add product builds a listing. Add video posts a clip that can open those listings.',
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: HubsomColors.forest,
            ),
      ),
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
