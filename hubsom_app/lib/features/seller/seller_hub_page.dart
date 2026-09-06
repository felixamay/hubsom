import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/hubsom_commission.dart';
import '../../core/providers/core_providers.dart';
import '../../core/services/admin_treasury_store.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../core/utils/money.dart';

class SellerHubPage extends ConsumerWidget {
  const SellerHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final pending =
        user == null ? 0.0 : AdminTreasuryStore.pendingFor(user);
    final links = [
      ('Store', '/seller/store', Icons.store),
      ('My products', '/seller/products', Icons.inventory_2_outlined),
      ('Add product', '/seller/products/new', Icons.add_box_outlined),
      ('Add video', '/videos/upload', Icons.movie_creation_outlined),
      ('Watch videos', '/videos', Icons.play_circle_outline),
      ('Orders & shipments', '/seller/orders', Icons.local_shipping_outlined),
      ('Go live', '/seller/go-live', Icons.videocam),
      ('Analytics', '/seller/analytics', Icons.insights),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Seller hub')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Manage your Hubsom store',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add product and Add video are separate. Products are listings; videos are short clips that can link to products.',
          ),
          const SizedBox(height: 12),
          Text(
            pending > 0
                ? 'Hubsom Admin is holding ${formatGhs(pending)} for you '
                    '(${HubsomCommission.sellerPercentLabel} after a '
                    '${HubsomCommission.percentLabel} sales commission). '
                    'Open Wallet to see payouts.'
                : 'Buyers pay Hubsom Admin. You receive '
                    '${HubsomCommission.sellerPercentLabel} of each sale after '
                    'a ${HubsomCommission.percentLabel} commission.',
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.account_balance_wallet_outlined, color: HubsomColors.forest),
            title: const Text('Sales payouts'),
            subtitle: Text(
              pending > 0
                  ? '${formatGhs(pending)} waiting on admin'
                  : '94% of sales, paid by admin',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/wallet'),
          ),
          const SizedBox(height: 16),
          ...links.map(
            (e) => ListTile(
              leading: Icon(e.$3, color: HubsomColors.forest),
              title: Text(e.$1),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(e.$2),
            ),
          ),
        ],
      ),
    );
  }
}
