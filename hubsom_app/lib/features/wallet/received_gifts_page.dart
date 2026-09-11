import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../../core/services/gift_store.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../core/utils/money.dart';
import '../../models/live_gift.dart';

class ReceivedGiftsPage extends ConsumerStatefulWidget {
  const ReceivedGiftsPage({super.key});

  @override
  ConsumerState<ReceivedGiftsPage> createState() => _ReceivedGiftsPageState();
}

class _ReceivedGiftsPageState extends ConsumerState<ReceivedGiftsPage> {
  bool _busy = false;

  Future<void> _withdraw() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    setState(() => _busy = true);
    try {
      final next = await GiftStore.withdrawEarnings(user);
      ref.read(authStateProvider.notifier).applyLocalUser(next);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${formatGhs(next.walletBalanceGhs - user.walletBalanceGhs)} moved to your wallet',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$e'.replaceFirst('Bad state: ', '').replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final sellerId = user?.sellerId ?? '';
    final pending = user == null ? 0.0 : GiftStore.pendingEarningsGhs(user);
    final received = GiftStore.receivedFor(sellerId);
    return Scaffold(
      appBar: AppBar(title: const Text('Received gifts')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [HubsomColors.gold, HubsomColors.forest],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gift earnings',
                  style: TextStyle(color: Colors.white70),
                ),
                Text(
                  formatGhs(pending),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '80% of each gift’s point value. Withdraw to your Hubsom wallet.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy || pending <= 0.001 ? null : _withdraw,
                  icon: const Icon(Icons.south_west),
                  label: Text(_busy ? 'Withdrawing…' : 'Withdraw to wallet'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Gifts received',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          if (received.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No gifts yet. When viewers send roses, crowns, and more on your live, they show up here.',
                ),
              ),
            )
          else
            ...received.map((e) => _ReceivedGiftTile(entry: e)),
        ],
      ),
    );
  }
}

class _ReceivedGiftTile extends StatelessWidget {
  const _ReceivedGiftTile({required this.entry});

  final GiftLedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final gift = entry.giftId == null ? null : GiftCatalog.byId(entry.giftId!);
    final share = entry.hostShareGhs ?? GiftCatalog.hostShareGhs(entry.points);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: HubsomColors.mist,
          child: Text(
            gift?.emoji ?? '🎁',
            style: const TextStyle(fontSize: 20),
          ),
        ),
        title: Text(
          gift?.name ?? entry.giftName ?? 'Gift',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${entry.senderName ?? 'Viewer'} · ${entry.points} pts · ${_when(entry.createdAt)}',
        ),
        trailing: Text(
          formatGhs(share),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: HubsomColors.forest,
          ),
        ),
      ),
    );
  }
}

String _when(String iso) {
  final dt = DateTime.tryParse(iso)?.toLocal();
  if (dt == null || iso.isEmpty) return '';
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  final h = dt.hour.toString().padLeft(2, '0');
  final min = dt.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $h:$min';
}
