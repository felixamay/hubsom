import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/hubsom_commission.dart';
import '../../core/providers/core_providers.dart';
import '../../core/services/admin_treasury_store.dart';
import '../../core/services/gift_store.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../core/utils/money.dart';
import '../../models/seller_payout.dart';
import '../../widgets/gift_points_sheet.dart';

class WalletPage extends ConsumerStatefulWidget {
  const WalletPage({super.key});

  @override
  ConsumerState<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends ConsumerState<WalletPage> {
  List<SellerPayout> _payouts = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPayouts());
  }

  Future<void> _loadPayouts() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    try {
      await AdminTreasuryStore.syncFromOrders();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _payouts = AdminTreasuryStore.payoutsFor(user));
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final hostEarnings =
        user == null ? 0.0 : GiftStore.pendingEarningsGhs(user);
    final pending = _payouts.where((p) => p.isPending).toList();
    final paid = _payouts.where((p) => p.isPaid).toList();
    final pendingGhs = pending.fold<double>(0, (s, p) => s + p.netGhs);
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
                if (pendingGhs > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Sales with admin ${formatGhs(pendingGhs)} · 94% after 6% fee',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
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
          Text(
            'Product sales are paid to Hubsom Admin first. Admin then pays you '
            '${HubsomCommission.sellerPercentLabel} of merchandise '
            '(${HubsomCommission.percentLabel} Hubsom commission). '
            'Your available balance is only money already paid out.',
          ),
          if (pending.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Waiting on admin',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            for (final payout in pending)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(payout.orderId),
                subtitle: Text(
                  'Sales ${formatGhs(payout.salesGhs)} · '
                  'Fee ${formatGhs(payout.commissionGhs)} · '
                  'You ${formatGhs(payout.netGhs)}',
                ),
              ),
          ],
          if (paid.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Paid by admin',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            for (final payout in paid.take(12))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(payout.orderId),
                subtitle: Text('Received ${formatGhs(payout.netGhs)}'),
              ),
          ],
          const SizedBox(height: 16),
          const Text(
            'Buy gift points to send roses, crowns, and more during live shows. '
            'Those payments also go to Hubsom Admin.',
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => GiftPointsSheet.show(context),
            icon: const Icon(Icons.card_giftcard),
            label: const Text('Buy gift points'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.push('/wallet/gifts'),
            icon: const Icon(Icons.redeem),
            label: Text(
              hostEarnings > 0
                  ? 'Received gifts · ${formatGhs(hostEarnings)} to withdraw'
                  : 'Received gifts & withdraw',
            ),
          ),
        ],
      ),
    );
  }
}
