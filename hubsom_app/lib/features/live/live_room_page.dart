import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/auth/require_auth.dart';
import '../../core/providers/core_providers.dart';
import '../../core/services/agora_service.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../core/utils/money.dart';
import '../../models/cart.dart';
import '../../models/product.dart';
import '../../models/stream.dart';
import '../../widgets/live_host_camera.dart';

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
  bool _following = false;
  bool _followBusy = false;
  bool _bidBusy = false;
  final _floating = <_FloatRx>[];
  Timer? _poll;
  Timer? _tick;
  late final AnimationController _pulse;

  bool get _isHost {
    if (widget.hostMode) return true;
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null || stream == null) return false;
    return user.sellerId == stream!.sellerId ||
        stream!.hosts.any((h) => h.id == user.id);
  }

  String get _hostName {
    final hosts = stream?.hosts;
    if (hosts != null && hosts.isNotEmpty && hosts.first.name.isNotEmpty) {
      return hosts.first.name;
    }
    return 'Host';
  }

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _load(join: true);
    _startPoll();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (stream?.auction?.isOpen == true) setState(() {});
    });
  }

  void _startPoll() {
    _poll?.cancel();
    final auctionOpen = stream?.auction?.isOpen == true;
    _poll = Timer.periodic(
      Duration(seconds: auctionOpen ? 2 : 4),
      (_) => _refreshQuiet(),
    );
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
          _following = ref
              .read(catalogRepositoryProvider)
              .isFollowingSeller(s.sellerId);
        });
        _startPoll();
      }

      if (!s.isLive) {
        if (mounted) await _goHomeAfterEnd();
        return;
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

  Future<void> _goHomeAfterEnd() async {
    _poll?.cancel();
    _tick?.cancel();
    await _agora?.leave();
    ref.invalidate(streamsProvider);
    if (!mounted) return;
    context.go('/');
  }

  Future<void> _refreshQuiet() async {
    if (!mounted || stream == null) return;
    try {
      final repo = ref.read(liveRepositoryProvider);
      final s = await repo.getStream(widget.streamId);
      final messages = await repo.listChat(widget.streamId);
      if (!mounted || s == null) return;
      if (stream!.isLive && !s.isLive) {
        await _goHomeAfterEnd();
        return;
      }
      Product? pin = pinned;
      final pinId = s.pinnedProductId ?? s.auction?.productId;
      if (pinId != null && pin?.id != pinId) {
        pin = await ref.read(catalogRepositoryProvider).getProduct(pinId);
      }
      final wasOpen = stream?.auction?.isOpen == true;
      final isOpen = s.auction?.isOpen == true;
      setState(() {
        stream = s;
        chat = messages;
        pinned = pin;
        _following = ref
            .read(catalogRepositoryProvider)
            .isFollowingSeller(s.sellerId);
      });
      if (wasOpen != isOpen) _startPoll();
    } catch (_) {}
  }

  Future<void> _shareShow() async {
    final s = stream;
    if (s == null) return;
    final uri = Uri.base.replace(
      path: '/live/${s.id}',
      query: '',
      fragment: '',
    );
    final link = uri.toString();
    final text =
        'Watch $_hostName live on Hubsom — ${s.title}\nBargain in real time:\n$link';
    try {
      await Share.share(text, subject: s.title);
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: link));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Live link copied — paste to share.')),
      );
    }
  }

  Future<void> _toggleFollow() async {
    final s = stream;
    if (s == null || _isHost || _followBusy) return;
    if (!ensureSignedIn(context, ref, message: 'Sign in to follow this seller')) {
      return;
    }
    setState(() => _followBusy = true);
    try {
      final catalog = ref.read(catalogRepositoryProvider);
      final next = _following
          ? await catalog.unfollowSeller(s.sellerId)
          : await catalog.followSeller(s.sellerId);
      if (!mounted) return;
      setState(() => _following = next);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            next ? 'Following $_hostName' : 'Unfollowed $_hostName',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
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
        content: const Text(
          'Viewers will no longer be able to join this show as live.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End live'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _ending = true);
    try {
      await ref.read(liveRepositoryProvider).endStream(widget.streamId);
      if (!mounted) return;
      await _goHomeAfterEnd();
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

  Future<void> _bidQuick() async {
    final a = stream?.auction;
    if (a == null || !a.isOpen) return;
    await _submitBid(a.nextMinBidGhs);
  }

  Future<void> _bidCustom() async {
    final a = stream?.auction;
    if (a == null || !a.isOpen) return;
    final min = a.nextMinBidGhs;
    final ctrl = TextEditingController(text: min.toStringAsFixed(0));
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Place your bid'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Minimum next bid: ${formatGhs(min)}',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Your bid (GHS)',
                prefixText: 'GH₵ ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text.trim());
              Navigator.pop(ctx, v);
            },
            child: const Text('Bid now'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (amount == null) return;
    await _submitBid(amount);
  }

  Future<void> _submitBid(double amount) async {
    if (!ensureSignedIn(context, ref, message: 'Sign in to place a bid')) {
      return;
    }
    final a = stream?.auction;
    if (a == null || _bidBusy) return;
    setState(() => _bidBusy = true);
    try {
      final auction =
          await ref.read(liveRepositoryProvider).placeBid(a.id, amount);
      if (!mounted) return;
      setState(() {
        stream = stream!.copyWith(auction: auction);
      });
      _startPoll();
      await _refreshQuiet();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bid placed — highest ${formatGhs(auction.currentBidGhs)}'
            '${auction.highestBidder == null ? '' : ' · ${auction.highestBidder}'}',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'.replaceFirst('Bad state: ', '').replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _bidBusy = false);
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
    _tick?.cancel();
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_goHomeAfterEnd());
      });
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: _Stage(
                stream: s,
                camOn: _camOn,
                micOn: _micOn,
                pulse: _pulse,
                isHost: _isHost,
                hostName: _hostName,
              ),
            ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
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
                  Expanded(
                    child: Text(
                      '$_hostName · ${s.viewerCount} watching',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  if (!_isHost)
                    TextButton(
                      onPressed: _followBusy ? null : _toggleFollow,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: _following
                            ? Colors.white24
                            : HubsomColors.live,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        _following ? 'Following' : 'Follow',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  IconButton(
                    tooltip: 'Share live',
                    onPressed: _shareShow,
                    icon: const Icon(Icons.ios_share, color: Colors.white),
                  ),
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
                    icon: const Icon(
                      Icons.shopping_bag_outlined,
                      color: Colors.white,
                    ),
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
                top: 64,
                child: _AuctionPanel(
                  auction: s.auction!,
                  isHost: _isHost,
                  bidBusy: _bidBusy,
                  onQuickBid: _bidQuick,
                  onCustomBid: _bidCustom,
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
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
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
                        final isBid = m.text.contains('Bid ') &&
                            m.text.contains('GHS');
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '${m.displayName}: ${m.text}',
                            style: TextStyle(
                              color: isBid
                                  ? HubsomColors.gold
                                  : Colors.white,
                              fontWeight:
                                  isBid ? FontWeight.w700 : FontWeight.w400,
                              shadows: const [
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
    required this.micOn,
    required this.pulse,
    required this.isHost,
    required this.hostName,
  });

  final LiveStream stream;
  final bool camOn;
  final bool micOn;
  final AnimationController pulse;
  final bool isHost;
  final String hostName;

  @override
  Widget build(BuildContext context) {
    if (isHost) {
      return LiveHostCamera(
        enabled: camOn,
        micOn: micOn,
        hostName: hostName,
      );
    }

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
                Color.lerp(
                  const Color(0xFF0B1F17),
                  HubsomColors.forest,
                  t * 0.25,
                )!,
                const Color(0xFF12261C),
                Color.lerp(
                  HubsomColors.ink,
                  const Color(0xFF1A3A2A),
                  t * 0.3,
                )!,
              ],
            ),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: HubsomColors.forest,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: HubsomColors.live.withValues(alpha: 0.45 + t * 0.2),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  hostName.isNotEmpty ? hostName[0].toUpperCase() : 'H',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                hostName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                stream.title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: HubsomColors.live.withValues(alpha: 0.85),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, color: HubsomColors.live, size: 10),
                    SizedBox(width: 8),
                    Text(
                      'Host is live · bid to bargain',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AuctionPanel extends StatelessWidget {
  const _AuctionPanel({
    required this.auction,
    required this.isHost,
    required this.bidBusy,
    required this.onQuickBid,
    required this.onCustomBid,
  });

  final LiveAuction auction;
  final bool isHost;
  final bool bidBusy;
  final VoidCallback onQuickBid;
  final VoidCallback onCustomBid;

  @override
  Widget build(BuildContext context) {
    final open = auction.isOpen;
    final left = auction.timeLeft ?? Duration.zero;
    final mins = left.inMinutes;
    final secs = left.inSeconds.remainder(60).toString().padLeft(2, '0');
    final history = auction.recentBids.take(4).toList();

    return Material(
      color: Colors.black.withValues(alpha: 0.78),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.gavel, color: HubsomColors.gold, size: 18),
                const SizedBox(width: 6),
                const Text(
                  'Live auction',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  open ? '$mins:$secs left' : 'Ended',
                  style: TextStyle(
                    color: open ? HubsomColors.gold : Colors.white70,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Highest bid  ${formatGhs(auction.currentBidGhs)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              auction.highestBidder == null
                  ? 'Opening · next ${formatGhs(auction.nextMinBidGhs)}'
                  : 'Leading: ${auction.highestBidder} · next ${formatGhs(auction.nextMinBidGhs)}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 12,
              ),
            ),
            if (history.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...history.map(
                (b) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '${b.bidderName} → ${formatGhs(b.amountGhs)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
            if (open && !isHost) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: HubsomColors.gold,
                        foregroundColor: HubsomColors.ink,
                      ),
                      onPressed: bidBusy ? null : onQuickBid,
                      child: Text(
                        bidBusy
                            ? 'Bidding…'
                            : 'Bid ${formatGhs(auction.nextMinBidGhs)}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: bidBusy ? null : onCustomBid,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                    ),
                    child: const Text('Custom'),
                  ),
                ],
              ),
            ],
            if (open && isHost)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Viewers are bidding live — stay on camera and call out the price.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
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
