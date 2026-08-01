import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/require_auth.dart';
import '../../core/providers/core_providers.dart';
import '../../core/services/agora_service.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../core/utils/money.dart';
import '../../models/cart.dart';
import '../../models/product.dart';
import '../../models/stream.dart';

class LiveRoomPage extends ConsumerStatefulWidget {
  const LiveRoomPage({super.key, required this.streamId, this.hostMode = false});
  final String streamId;
  final bool hostMode;

  @override
  ConsumerState<LiveRoomPage> createState() => _LiveRoomPageState();
}

class _LiveRoomPageState extends ConsumerState<LiveRoomPage>
    with TickerProviderStateMixin {
  LiveStream? stream;
  List<ChatMessage> chat = [];
  List<Product> bag = [];
  Product? pinned;
  final _chatCtrl = TextEditingController();
  String? error;
  AgoraService? _agora;
  bool _micOn = true;
  bool _camOn = true;
  bool _ending = false;
  bool _shopOpen = false;
  final _floating = <_FloatRx>[];
  Timer? _poll;
  late final AnimationController _pulse;

  bool get _isHost {
    if (widget.hostMode) return true;
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null || stream == null) return false;
    return user.sellerId == stream!.sellerId ||
        stream!.hosts.any((h) => h.id == user.id);
  }

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _load(join: true);
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _refreshQuiet());
  }

  Future<void> _load({bool join = false}) async {
    try {
      final repo = ref.read(liveRepositoryProvider);
      final s = await repo.getStream(widget.streamId, joinAsViewer: join);
      if (s == null) {
        if (mounted) setState(() => error = 'Live show not found');
        return;
      }

      // Paint the room immediately so go-live never lands on a blank page.
      if (mounted) {
        setState(() {
          stream = s;
          error = null;
        });
      }

      final messages = await repo.listChat(widget.streamId);
      final products = <Product>[];
      for (final id in s.productIds) {
        final p = await ref.read(catalogRepositoryProvider).getProduct(id);
        if (p != null) products.add(p);
      }
      Product? pin;
      final pinId = s.pinnedProductId ?? s.auction?.productId;
      if (pinId != null) {
        for (final p in products) {
          if (p.id == pinId) {
            pin = p;
            break;
          }
        }
        pin ??= await ref.read(catalogRepositoryProvider).getProduct(pinId);
      }

      if (!mounted) return;
      setState(() {
        chat = messages;
        bag = products;
        pinned = pin;
      });

      if (join) {
        // Non-blocking: web uses a stub so this must never freeze the UI.
        // ignore: unawaited_futures
        _joinAgora(s);
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> _joinAgora(LiveStream s) async {
    try {
      _agora = ref.read(agoraServiceProvider);
      final token = await _agora!.fetchToken(
        channelName: s.channelName,
        uid: widget.hostMode ? 1 : 0,
        role: widget.hostMode ? 'publisher' : 'subscriber',
      );
      if (widget.hostMode) {
        await _agora!.joinAsHost(
          channelName: s.channelName,
          token: token ?? '',
          uid: 1,
        );
      } else {
        await _agora!.joinAsAudience(
          channelName: s.channelName,
          token: token ?? '',
        );
      }
    } catch (_) {
      // Live commerce UI still works without RTC.
    }
  }

  Future<void> _refreshQuiet() async {
    if (!mounted || stream == null) return;
    try {
      final repo = ref.read(liveRepositoryProvider);
      final s = await repo.getStream(widget.streamId);
      final messages = await repo.listChat(widget.streamId);
      if (!mounted || s == null) return;
      Product? pin = pinned;
      final pinId = s.pinnedProductId ?? s.auction?.productId;
      if (pinId != null && pin?.id != pinId) {
        pin = await ref.read(catalogRepositoryProvider).getProduct(pinId);
      }
      setState(() {
        stream = s;
        chat = messages;
        pinned = pin;
      });
    } catch (_) {}
  }

  Future<void> _react() async {
    if (!ensureSignedIn(context, ref, message: 'Sign in to react')) return;
    final rx = await ref
        .read(liveRepositoryProvider)
        .sendReaction(widget.streamId, '❤️');
    final entry = _FloatRx(
      id: rx.id,
      emoji: rx.emoji,
      x: rx.x,
      controller: AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1600),
      ),
    );
    setState(() => _floating.add(entry));
    entry.controller.forward().whenComplete(() {
      entry.controller.dispose();
      if (mounted) setState(() => _floating.removeWhere((e) => e.id == rx.id));
    });
  }

  Future<void> _endLive() async {
    if (_ending || stream == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End live show?'),
        content: const Text('Viewers will no longer be able to join this show as live.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('End live')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _ending = true);
    try {
      final ended =
          await ref.read(liveRepositoryProvider).endStream(widget.streamId);
      await _agora?.leave();
      ref.invalidate(streamsProvider);
      if (!mounted) return;
      setState(() {
        stream = ended;
        _ending = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _ending = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _pin(Product product) async {
    final updated = await ref
        .read(liveRepositoryProvider)
        .pinProduct(widget.streamId, product.id);
    setState(() {
      stream = updated;
      pinned = product;
      _shopOpen = false;
    });
  }

  Future<void> _buy(Product product) async {
    if (!ensureSignedIn(context, ref, message: 'Sign in to buy from live')) {
      return;
    }
    ref.read(cartProvider.notifier).add(
          CartItem(
            productId: product.id,
            quantity: 1,
            source: 'live',
            streamId: stream!.id,
            name: product.name,
            priceGhs: product.effectivePrice,
            image: product.images.isNotEmpty ? product.images.first : null,
            category: product.category,
          ),
        );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Added to bag from live')),
    );
  }

  Future<void> _bid() async {
    if (!ensureSignedIn(context, ref, message: 'Sign in to place a bid')) {
      return;
    }
    final a = stream?.auction;
    if (a == null) return;
    final next = a.currentBidGhs + a.minIncrementGhs;
    try {
      await ref.read(liveRepositoryProvider).placeBid(a.id, next);
      await _refreshQuiet();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _sendChat() async {
    if (!ensureSignedIn(context, ref, message: 'Sign in to chat')) return;
    final text = _chatCtrl.text.trim();
    if (text.isEmpty) return;
    try {
      await ref.read(liveRepositoryProvider).sendChat(stream!.id, text);
      _chatCtrl.clear();
      await _refreshQuiet();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _pulse.dispose();
    _chatCtrl.dispose();
    for (final f in _floating) {
      f.controller.dispose();
    }
    _agora?.leave();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error!),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => context.go('/live'),
                child: const Text('Back to live'),
              ),
            ],
          ),
        ),
      );
    }
    if (stream == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final s = stream!;
    if (!s.isLive) {
      return Scaffold(
        backgroundColor: HubsomColors.ink,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'SHOW ENDED',
                  style: TextStyle(
                    color: HubsomColors.gold,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  s.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isHost
                      ? 'You ended this live show.'
                      : 'The host ended this live show.',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => context.go(_isHost ? '/seller' : '/live'),
                  child: Text(_isHost ? 'Seller hub' : 'Browse live'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _Stage(stream: s, camOn: _camOn, pulse: _pulse, isHost: _isHost)),
            // Floating reactions
            ..._floating.map((f) {
              return AnimatedBuilder(
                animation: f.controller,
                builder: (_, __) {
                  final t = f.controller.value;
                  return Positioned(
                    left: MediaQuery.sizeOf(context).width * f.x.clamp(0.2, 0.85),
                    bottom: 120 + (220 * t),
                    child: Opacity(
                      opacity: (1 - t).clamp(0, 1),
                      child: Text(f.emoji, style: const TextStyle(fontSize: 28)),
                    ),
                  );
                },
              );
            }),
            Positioned(
              left: 8,
              top: 4,
              right: 8,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.go('/live'),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  ScaleTransition(
                    scale: Tween(begin: 0.95, end: 1.05).animate(_pulse),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      color: HubsomColors.live,
                      child: const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${s.viewerCount} watching',
                    style: const TextStyle(color: Colors.white),
                  ),
                  const Spacer(),
                  if (_isHost)
                    IconButton(
                      tooltip: _micOn ? 'Mute' : 'Unmute',
                      onPressed: () => setState(() => _micOn = !_micOn),
                      icon: Icon(
                        _micOn ? Icons.mic : Icons.mic_off,
                        color: Colors.white,
                      ),
                    ),
                  if (_isHost)
                    IconButton(
                      tooltip: _camOn ? 'Camera off' : 'Camera on',
                      onPressed: () => setState(() => _camOn = !_camOn),
                      icon: Icon(
                        _camOn ? Icons.videocam : Icons.videocam_off,
                        color: Colors.white,
                      ),
                    ),
                  IconButton(
                    onPressed: _react,
                    icon: const Icon(Icons.favorite, color: Colors.pinkAccent),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _shopOpen = !_shopOpen),
                    icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white),
                  ),
                  if (_isHost)
                    IconButton(
                      onPressed: _ending ? null : _endLive,
                      icon: const Icon(Icons.call_end, color: Colors.redAccent),
                    ),
                ],
              ),
            ),
            if (s.auction != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 250,
                child: Material(
                  color: HubsomColors.gold,
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    title: Text(
                      'Auction · ${formatGhs(s.auction!.currentBidGhs)}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      'Min +${formatGhs(s.auction!.minIncrementGhs)} · ${s.auction!.bidderCount} bidders',
                    ),
                    trailing: _isHost
                        ? null
                        : FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: HubsomColors.forest,
                            ),
                            onPressed: _bid,
                            child: const Text('Bid'),
                          ),
                  ),
                ),
              ),
            if (pinned != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 180,
                child: Material(
                  color: Colors.white.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    title: Text(
                      pinned!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(formatGhs(pinned!.effectivePrice)),
                    trailing: FilledButton(
                      onPressed: () => _buy(pinned!),
                      child: const Text('Buy'),
                    ),
                  ),
                ),
              ),
            if (_shopOpen)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Material(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: SizedBox(
                    height: min(360, MediaQuery.sizeOf(context).height * 0.45),
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(
                            _isHost ? 'Pin a product' : 'Live bag',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          trailing: IconButton(
                            onPressed: () => setState(() => _shopOpen = false),
                            icon: const Icon(Icons.close),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: bag.length,
                            itemBuilder: (_, i) {
                              final p = bag[i];
                              return ListTile(
                                title: Text(p.name),
                                subtitle: Text(formatGhs(p.effectivePrice)),
                                trailing: _isHost
                                    ? TextButton(
                                        onPressed: () => _pin(p),
                                        child: Text(
                                          pinned?.id == p.id ? 'Pinned' : 'Pin',
                                        ),
                                      )
                                    : FilledButton(
                                        onPressed: () => _buy(p),
                                        child: const Text('Buy'),
                                      ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 110,
                    child: ListView(
                      reverse: true,
                      children: chat.take(30).map((m) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '${m.displayName}: ${m.text}',
                            style: const TextStyle(
                              color: Colors.white,
                              shadows: [
                                Shadow(blurRadius: 6, color: Colors.black),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _chatCtrl,
                          style: const TextStyle(color: Colors.white),
                          onSubmitted: (_) => _sendChat(),
                          decoration: InputDecoration(
                            hintText: 'Say something…',
                            hintStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.white24,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _sendChat,
                        icon: const Icon(Icons.send, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage({
    required this.stream,
    required this.camOn,
    required this.pulse,
    required this.isHost,
  });

  final LiveStream stream;
  final bool camOn;
  final AnimationController pulse;
  final bool isHost;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        final t = pulse.value;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(const Color(0xFF0B1F17), HubsomColors.forest, t * 0.25)!,
                const Color(0xFF12261C),
                Color.lerp(HubsomColors.ink, const Color(0xFF1A3A2A), t * 0.3)!,
              ],
            ),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isHost
                    ? (camOn ? Icons.videocam : Icons.videocam_off)
                    : Icons.live_tv,
                color: Colors.white.withValues(alpha: 0.55 + t * 0.25),
                size: 76,
              ),
              const SizedBox(height: 12),
              Text(
                stream.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isHost
                    ? (camOn
                        ? 'You are live - ${stream.channelName}'
                        : 'Camera off - audio ${stream.channelName}')
                    : 'Watching - ${stream.channelName}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FloatRx {
  _FloatRx({
    required this.id,
    required this.emoji,
    required this.x,
    required this.controller,
  });
  final String id;
  final String emoji;
  final double x;
  final AnimationController controller;
}
