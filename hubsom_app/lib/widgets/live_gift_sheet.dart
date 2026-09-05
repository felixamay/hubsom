import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/core_providers.dart';
import '../core/theme/hubsom_colors.dart';
import '../models/live_gift.dart';
import 'gift_points_sheet.dart';

class LiveGiftSheet extends ConsumerWidget {
  const LiveGiftSheet({
    super.key,
    required this.streamId,
    required this.hostMode,
    required this.onSent,
  });

  final String streamId;
  final bool hostMode;
  final void Function(LiveGift gift) onSent;

  static Future<LiveGift?> show(
    BuildContext context, {
    required String streamId,
    required bool hostMode,
  }) {
    return showModalBottomSheet<LiveGift>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => LiveGiftSheet(
        streamId: streamId,
        hostMode: hostMode,
        onSent: (gift) => Navigator.pop(ctx, gift),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final points = user?.giftPoints ?? 0;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.paddingOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Send a gift',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const Spacer(),
              Text(
                '$points pts',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: HubsomColors.gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            hostMode
                ? 'Viewers buy points and send these gifts during your live.'
                : 'Pick a gift. Points are purchased in Wallet or here.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.78,
            children: [
              for (final gift in GiftCatalog.gifts)
                _GiftTile(
                  gift: gift,
                  canAfford: points >= gift.costPoints,
                  enabled: !hostMode,
                  onTap: () async {
                    if (hostMode) return;
                    try {
                      final result = await ref
                          .read(liveRepositoryProvider)
                          .sendGift(streamId: streamId, giftId: gift.id);
                      ref
                          .read(authStateProvider.notifier)
                          .applyLocalUser(result.user);
                      onSent(result.gift);
                    } catch (e) {
                      if (!context.mounted) return;
                      final msg = '$e'
                          .replaceFirst('Bad state: ', '')
                          .replaceFirst('Exception: ', '');
                      if (msg.contains('Buy points')) {
                        await GiftPointsSheet.show(context);
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(msg)),
                      );
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (!hostMode)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => GiftPointsSheet.show(context),
                icon: const Icon(Icons.add),
                label: const Text('Buy gift points'),
              ),
            ),
        ],
      ),
    );
  }
}

class _GiftTile extends StatelessWidget {
  const _GiftTile({
    required this.gift,
    required this.canAfford,
    required this.enabled,
    required this.onTap,
  });

  final LiveGift gift;
  final bool canAfford;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HubsomColors.mist,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(gift.emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(height: 4),
              Text(
                gift.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
              Text(
                '${gift.costPoints} pts',
                style: TextStyle(
                  fontSize: 10,
                  color: canAfford ? HubsomColors.forest : Colors.black45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
