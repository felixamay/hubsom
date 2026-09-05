import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/core_providers.dart';
import '../core/theme/hubsom_colors.dart';
import '../core/utils/money.dart';
import '../models/live_gift.dart';

/// Buy live-gift points with wallet or a payment rail.
class GiftPointsSheet extends ConsumerStatefulWidget {
  const GiftPointsSheet({super.key, this.popOnSuccess = true});

  /// When false, stay on the current page after a successful purchase.
  final bool popOnSuccess;

  static Future<bool> show(BuildContext context) async {
    final bought = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const GiftPointsSheet(),
    );
    return bought == true;
  }

  @override
  ConsumerState<GiftPointsSheet> createState() => _GiftPointsSheetState();
}

class _GiftPointsSheetState extends ConsumerState<GiftPointsSheet> {
  String _method = 'mtn-momo';
  bool _busy = false;
  String? _error;

  static const _methods = <(String, String)>[
    ('mtn-momo', 'MTN MoMo'),
    ('telecel-cash', 'Telecel Cash'),
    ('airteltigo-money', 'AirtelTigo Money'),
    ('wallet', 'Hubsom wallet'),
    ('paystack', 'Card / Paystack'),
  ];

  Future<void> _buy(GiftPointPack pack) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await ref.read(liveRepositoryProvider).buyGiftPoints(
            packId: pack.id,
            paymentMethod: _method,
          );
      ref.read(authStateProvider.notifier).applyLocalUser(user);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      if (widget.popOnSuccess) {
        Navigator.pop(context, true);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Added ${pack.points} gift points · ${user.giftPoints} pts now',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            '$e'.replaceFirst('Bad state: ', '').replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.paddingOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Buy gift points',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Balance ${user?.giftPoints ?? 0} pts · Wallet ${formatGhs(user?.walletBalanceGhs ?? 0)}',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final m in _methods)
                ChoiceChip(
                  label: Text(m.$2),
                  selected: _method == m.$1,
                  onSelected: _busy ? null : (_) => setState(() => _method = m.$1),
                ),
            ],
          ),
          const SizedBox(height: 12),
          for (final pack in GiftCatalog.packs)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${pack.points} points',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(formatGhs(pack.priceGhs)),
              trailing: FilledButton(
                onPressed: _busy ? null : () => _buy(pack),
                child: const Text('Buy'),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 4),
          Text(
            'Points stay on your account and are spent on live gifts. '
            'Hosts receive 80% of the gift value.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: HubsomColors.forest,
                ),
          ),
        ],
      ),
    );
  }
}
