import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../../core/services/agora_service.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../core/utils/money.dart';
import '../../models/cart.dart';
import '../../models/product.dart';
import '../../models/stream.dart';

class LiveRoomPage extends ConsumerStatefulWidget {
  const LiveRoomPage({super.key, required this.streamId});
  final String streamId;

  @override
  ConsumerState<LiveRoomPage> createState() => _LiveRoomPageState();
}

class _LiveRoomPageState extends ConsumerState<LiveRoomPage> {
  LiveStream? stream;
  List<ChatMessage> chat = [];
  final _chatCtrl = TextEditingController();
  Product? pinned;
  String? error;
  AgoraService? _agora;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(liveRepositoryProvider);
      final s = await repo.getStream(widget.streamId);
      final messages = await repo.listChat(widget.streamId);
      Product? pin;
      if (s?.pinnedProductId != null) {
        pin = await ref.read(catalogRepositoryProvider).getProduct(s!.pinnedProductId!);
      }
      // Join Agora as audience when configured
      if (s != null) {
        _agora = ref.read(agoraServiceProvider);
        final token = await _agora!.fetchToken(channelName: s.channelName, uid: 0);
        if (token != null) {
          await _agora!.joinAsAudience(channelName: s.channelName, token: token);
        }
      }
      if (!mounted) return;
      setState(() {
        stream = s;
        chat = messages;
        pinned = pin;
      });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  @override
  void dispose() {
    _chatCtrl.dispose();
    _agora?.leave();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Scaffold(appBar: AppBar(), body: Center(child: Text(error!)));
    }
    if (stream == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final s = stream!;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                color: HubsomColors.ink,
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.live_tv, color: Colors.white54, size: 72),
                    const SizedBox(height: 8),
                    Text(s.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                    Text('Agora channel: ${s.channelName}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 12, top: 8, right: 12,
              child: Row(children: [
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white)),
                if (s.isLive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    color: HubsomColors.live,
                    child: const Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
                  ),
                const SizedBox(width: 8),
                Text('${s.viewerCount} watching', style: const TextStyle(color: Colors.white)),
                const Spacer(),
                IconButton(
                  onPressed: () => ref.read(liveRepositoryProvider).sendReaction(s.id, '❤️'),
                  icon: const Icon(Icons.favorite, color: Colors.pinkAccent),
                ),
              ]),
            ),
            if (pinned != null)
              Positioned(
                left: 12, right: 12, bottom: 160,
                child: Material(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    title: Text(pinned!.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(formatGhs(pinned!.effectivePrice)),
                    trailing: FilledButton(
                      onPressed: () {
                        ref.read(cartProvider.notifier).add(CartItem(
                          productId: pinned!.id,
                          quantity: 1,
                          source: 'live',
                          streamId: s.id,
                          name: pinned!.name,
                          priceGhs: pinned!.effectivePrice,
                          image: pinned!.images.isNotEmpty ? pinned!.images.first : null,
                          category: pinned!.category,
                        ));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added from live bag')));
                      },
                      child: const Text('Buy'),
                    ),
                  ),
                ),
              ),
            if (s.auction != null)
              Positioned(
                left: 12, right: 12, bottom: 230,
                child: Material(
                  color: HubsomColors.gold,
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    title: Text('Auction · ${formatGhs(s.auction!.currentBidGhs)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('Min +${formatGhs(s.auction!.minIncrementGhs)} · ${s.auction!.bidderCount} bidders'),
                    trailing: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: HubsomColors.forest),
                      onPressed: () async {
                        final next = s.auction!.currentBidGhs + s.auction!.minIncrementGhs;
                        await ref.read(liveRepositoryProvider).placeBid(s.auction!.id, next);
                        await _load();
                      },
                      child: const Text('Bid'),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 12, right: 12, bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 100,
                    child: ListView(
                      children: chat.take(20).map((m) => Text(
                        '${m.displayName}: ${m.text}',
                        style: const TextStyle(color: Colors.white, shadows: [Shadow(blurRadius: 4, color: Colors.black)]),
                      )).toList(),
                    ),
                  ),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _chatCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Say something…',
                          hintStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white24,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        final text = _chatCtrl.text.trim();
                        if (text.isEmpty) return;
                        await ref.read(liveRepositoryProvider).sendChat(s.id, text);
                        _chatCtrl.clear();
                        await _load();
                      },
                      icon: const Icon(Icons.send, color: Colors.white),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
