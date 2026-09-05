import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../../core/services/gift_store.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../core/utils/money.dart';
import '../../widgets/gift_points_sheet.dart';

class WalletPage extends ConsumerWidget {
  const WalletPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final sellerId = user?.sellerId ?? '';
    final storedHost = sellerId.isEmpty ? 0.0 : GiftStore.hostEarnings(sellerId);
    final fromUser = user?.giftEarningsGhs ?? 0;
    final hostEarnings = fromUser > storedHost ? fromUser : storedHost;
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [HubsomColors.forest, HubsomColors.blue],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Available balance',
                  style: TextStyle(color: Colors.white70),
                ),
                Text(
                  formatGhs(user?.walletBalanceGhs ?? 0),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Gift points ${user?.giftPoints ?? 0}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (hostEarnings > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Live gift earnings ${formatGhs(hostEarnings)}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Buy gift points to send roses, crowns, and more during live shows. '
            'Pay with MoMo, card, or your Hubsom wallet.',
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => GiftPointsSheet.show(context),
            icon: const Icon(Icons.card_giftcard),
            label: const Text('Buy gift points'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Gift points are separate from your shopping wallet. '
            'Pay with MoMo, Telecel, AirtelTigo, card, or deduct from wallet GHS.',
          ),
        ],
      ),
    );
  }
}
