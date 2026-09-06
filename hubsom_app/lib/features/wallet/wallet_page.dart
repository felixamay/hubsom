import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/core_providers.dart';
import '../../core/services/gift_store.dart';
import '../../core/services/payment_account_store.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../core/utils/money.dart';
import '../../widgets/gift_points_sheet.dart';

class WalletPage extends ConsumerStatefulWidget {
  const WalletPage({super.key});

  @override
  ConsumerState<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends ConsumerState<WalletPage> {
  final _amount = TextEditingController();
  final _handle = TextEditingController();
  String _rail = 'mtn-momo';
  bool _busy = false;
  String? _error;

  static const _rails = <(String, String)>[
    ('mtn-momo', 'MTN MoMo'),
    ('telecel-cash', 'Telecel Cash'),
    ('airteltigo-money', 'AirtelTigo Money'),
  ];

  @override
  void dispose() {
    _amount.dispose();
    _handle.dispose();
    super.dispose();
  }

  Future<void> _withdraw() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await PaymentAccountStore.withdraw(
        user: user,
        amountGhs: amount,
        rail: _rail,
        handle: _handle.text.trim(),
      );
      ref.read(authStateProvider.notifier).applyLocalUser(result.user);
      if (!mounted) return;
      _amount.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Withdrew ${formatGhs(amount)}')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e'.replaceFirst('Bad state: ', '').replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final hostEarnings =
        user == null ? 0.0 : GiftStore.pendingEarningsGhs(user);
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
                  'Withdrawable balance',
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
            'This payment account is for withdrawals only. '
            'It cannot receive product payments.',
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
          const SizedBox(height: 20),
          Text(
            'Withdraw',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final rail in _rails)
                ChoiceChip(
                  label: Text(rail.$2),
                  selected: _rail == rail.$1,
                  onSelected: _busy ? null : (_) => setState(() => _rail = rail.$1),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _handle,
            keyboardType: TextInputType.phone,
            enabled: !_busy,
            decoration: const InputDecoration(labelText: 'MoMo number'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            enabled: !_busy,
            decoration: const InputDecoration(labelText: 'Amount (GHS)'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy || user == null ? null : _withdraw,
            icon: const Icon(Icons.outbox_outlined),
            label: Text(_busy ? 'Withdrawing…' : 'Withdraw'),
          ),
        ],
      ),
    );
  }
}
