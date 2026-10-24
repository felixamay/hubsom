import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../core/utils/money.dart';

class HuberWalletPage extends ConsumerWidget {
  const HuberWalletPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final profile = user == null
        ? null
        : ref.watch(huberRepositoryProvider).profileFor(user);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Text(
          'Wallet',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: HubsomColors.huberNavy,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          formatGhs(profile?.walletBalanceGhs ?? 0),
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 8),
        const Text('Available after completed Hubsom deliveries.'),
        const SizedBox(height: 24),
        const Text('No withdrawal methods yet. Add one after your first payout.'),
      ],
    );
  }
}
