import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../core/utils/money.dart';

class WalletPage extends ConsumerWidget {
  const WalletPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [HubsomColors.forest, HubsomColors.blue]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Available balance', style: TextStyle(color: Colors.white70)),
              Text(formatGhs(user?.walletBalanceGhs ?? 0),
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
            ]),
          ),
          const SizedBox(height: 16),
          const Text('Top up / payout via Stripe, Paystack, MTN MoMo, Telecel Cash, or AirtelTigo Money.'),
          const SizedBox(height: 12),
          FilledButton(onPressed: () {}, child: const Text('Top up')),
          OutlinedButton(onPressed: () {}, child: const Text('Request payout')),
        ],
      ),
    );
  }
}
