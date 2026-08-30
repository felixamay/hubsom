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
import '../../widgets/hubsom_image.dart';
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
  List<Product> _catalog = const [];
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
  bool _extendBusy = false;
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
      final auction = stream?.auction;
      if (auction == null) return;
      if (auction.needsFinalize) {
        unawaited(
          ref
              .read(liveRepositoryProvider)
              .finalizeAuctionIfNeeded(widget.streamId)
              .then((s) {
            if (!mounted || s == null) return;
            setState(() => stream = s);
            _startPoll();
          }),
        );
      } else if (auction.isOpen || auction.awaitingExtend) {
        // Mark reserve_not_met for host UI when the clock hits zero.
        if (auction.awaitingExtend && auction.status == 'open') {
          unawaited(
            ref
                .read(liveRepositoryProvider)
                .finalizeAuctionIfNeeded(widget.streamId)
                .then((s) {
              if (!mounted || s == null) return;
              setState(() => stream = s);
            }),
          );
        }
        setState(() {});
      }
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

      List<Product> catalog = _catalog;
      if (_isHost || widget.hostMode) {
        try {
          catalog = await ref.read(sellerRepositoryProvider).myProducts();
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        chat = messages;
        bag = products;
        pinned = pin;
        _catalog = catalog;
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
      LiveStream next = s;
      if (s.auction?.needsFinalize == true) {
        final finalized =
            await repo.finalizeAuctionIfNeeded(widget.streamId);
        if (finalized != null) next = finalized;
      }
      Product? pin = pinned;
      final pinId = next.pinnedProductId ?? next.auction?.productId;
      if (pinId != null && pin?.id != pinId) {
        pin = await ref.read(catalogRepositoryProvider).getProduct(pinId);
      }
      final wasOpen = stream?.auction?.isOpen == true;
      final isOpen = next.auction?.isOpen == true;
      setState(() {
        stream = next;
        chat = messages;
        pinned = pin;
        _following = ref
            .read(catalogRepositoryProvider)
            .isFollowingSeller(next.sellerId);
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
      if (!bag.any((p) => p.id == product.id)) {
        bag = [...bag, product];
      }
      _shopOpen = false;
    });
  }

  Future<void> _addProductToLive(Product product) async {
    try {
      final updated = await ref
          .read(liveRepositoryProvider)
          .addProducts(widget.streamId, [product.id]);
      // Also pin the newly added product so viewers see it right away.
      final pinnedStream = await ref
          .read(liveRepositoryProvider)
          .pinProduct(widget.streamId, product.id);
      if (!mounted) return;
      setState(() {
        stream = pinnedStream.productIds.contains(product.id)
            ? pinnedStream
            : updated;
        pinned = product;
        if (!bag.any((p) => p.id == product.id)) {
          bag = [...bag, product];
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added & pinned ${product.name}')),
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
    }
  }

  Future<void> _openShop() async {
    if (_isHost) {
      try {
        final catalog = await ref.read(sellerRepositoryProvider).myProducts();
        if (mounted) setState(() => _catalog = catalog);
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() => _shopOpen = !_shopOpen);
  }

  Future<void> _extendAuction() async {
    if (_extendBusy || stream?.auction == null) return;
    setState(() => _extendBusy = true);
    try {
      final auction = await ref
          .read(liveRepositoryProvider)
          .extendAuction(widget.streamId, seconds: 30);
      if (!mounted) return;
      setState(() {
        stream = stream!.copyWith(auction: auction);
      });
      _startPoll();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Auction extended +30 seconds')),
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
      if (mounted) setState(() => _extendBusy = false);
    }
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
                  if (_isHost)
                    TextButton(
                      onPressed: _openShop,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: HubsomColors.gold,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Add products',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: HubsomColors.ink,
                        ),
                      ),
                    ),
                  IconButton(
                    onPressed: _react,
                    icon: const Icon(Icons.favorite, color: Colors.pinkAccent),
                  ),
                  IconButton(
                    tooltip: _isHost ? 'Live products' : 'Live bag',
                    onPressed: _openShop,
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
            if (!_shopOpen)
              // Chat floats above the bottom auction / bid dock (TikTok-style).
              Positioned(
              left: 12,
              right: MediaQuery.sizeOf(context).width * 0.28,
              bottom: s.auction != null
                  ? (_isHost ? 200 : 210)
                  : (pinned != null ? 140 : 72),
              child: SizedBox(
                height: 150,
                child: ListView(
                  reverse: true,
                  children: chat.take(30).map((m) {
                    final isBid =
                        m.text.contains('Bid ') && m.text.contains('GHS');
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${m.displayName}: ${m.text}',
                        style: TextStyle(
                          color: isBid ? HubsomColors.gold : Colors.white,
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
            ),
            if (!_shopOpen)
              Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _LiveBottomDock(
                auction: s.auction,
                pinned: pinned,
                isHost: _isHost,
                bidBusy: _bidBusy,
                extendBusy: _extendBusy,
                chatCtrl: _chatCtrl,
                onQuickBid: _bidQuick,
                onCustomBid: _bidCustom,
                onExtend: _extendAuction,
                onBuyPinned: pinned == null ? null : () => _buy(pinned!),
                onSendChat: _sendChat,
              ),
            ),
            // Host/viewer product sheet sits above the dock so Add products works.
            if (_shopOpen)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: () => setState(() => _shopOpen = false),
                  child: Container(color: Colors.black54),
                ),
              ),
            if (_shopOpen)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Material(
                  color: Colors.white,
                  elevation: 12,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: SizedBox(
                    height: min(480, MediaQuery.sizeOf(context).height * 0.65),
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(
                            _isHost ? 'Add products to live' : 'Live bag',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: _isHost
                              ? const Text(
                                  'Tap Add to bring a catalog item into this show',
                                )
                              : null,
                          trailing: IconButton(
                            onPressed: () => setState(() => _shopOpen = false),
                            icon: const Icon(Icons.close),
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            children: [
                              if (bag.isNotEmpty)
                                const Padding(
                                  padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
                                  child: Text(
                                    'In this show',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ...bag.map((p) {
                                return ListTile(
                                  title: Text(p.name),
                                  subtitle: Text(formatGhs(p.effectivePrice)),
                                  trailing: _isHost
                                      ? TextButton(
                                          onPressed: () => _pin(p),
                                          child: Text(
                                            pinned?.id == p.id
                                                ? 'Pinned'
                                                : 'Pin',
                                          ),
                                        )
                                      : FilledButton(
                                          onPressed: () => _buy(p),
                                          child: const Text('Buy'),
                                        ),
                                );
                              }),
                              if (_isHost) ...[
                                const Divider(),
                                const Padding(
                                  padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
                                  child: Text(
                                    'Your catalog',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                if (_catalog
                                    .where(
                                      (p) => !bag.any((b) => b.id == p.id),
                                    )
                                    .isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(
                                      _catalog.isEmpty
                                          ? 'No products in your catalog yet. Create one from Seller hub, then Add here.'
                                          : 'All your products are already in this live show.',
                                    ),
                                  )
                                else
                                  ..._catalog
                                      .where(
                                        (p) => !bag.any((b) => b.id == p.id),
                                      )
                                      .map(
                                        (p) => ListTile(
                                          leading: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: SizedBox(
                                              width: 44,
                                              height: 44,
                                              child: HubsomImage(
                                                url: p.images.isNotEmpty
                                                    ? p.images.first
                                                    : null,
                                                width: 44,
                                                height: 44,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                          title: Text(p.name),
                                          subtitle: Text(
                                            formatGhs(p.effectivePrice),
                                          ),
                                          trailing: FilledButton(
                                            onPressed: () =>
                                                _addProductToLive(p),
                                            child: const Text('Add'),
                                          ),
                                        ),
                                      ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
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

class _LiveBottomDock extends StatelessWidget {
  const _LiveBottomDock({
    required this.auction,
    required this.pinned,
    required this.isHost,
    required this.bidBusy,
    required this.extendBusy,
    required this.chatCtrl,
    required this.onQuickBid,
    required this.onCustomBid,
    required this.onExtend,
    required this.onBuyPinned,
    required this.onSendChat,
  });

  final LiveAuction? auction;
  final Product? pinned;
  final bool isHost;
  final bool bidBusy;
  final bool extendBusy;
  final TextEditingController chatCtrl;
  final VoidCallback onQuickBid;
  final VoidCallback onCustomBid;
  final VoidCallback onExtend;
  final VoidCallback? onBuyPinned;
  final VoidCallback onSendChat;

  @override
  Widget build(BuildContext context) {
    final a = auction;
    final left = a?.timeLeft ?? Duration.zero;
    final secsLeft = left.inSeconds.clamp(0, 30);
    final open = a?.isOpen == true;
    final awaiting = a?.awaitingExtend == true;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.55),
            Colors.black.withValues(alpha: 0.88),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (a != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white24),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: pinned != null && pinned!.images.isNotEmpty
                        ? HubsomImage(
                            url: pinned!.images.first,
                            width: 54,
                            height: 54,
                            fit: BoxFit.cover,
                          )
                        : const Icon(Icons.gavel, color: HubsomColors.gold),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pinned?.name ?? 'Live auction',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formatGhs(a.currentBidGhs),
                          style: const TextStyle(
                            color: HubsomColors.gold,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          a.highestBidder == null
                              ? 'Opening bid'
                              : 'Leading · ${a.highestBidder}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 11,
                          ),
                        ),
                        if (isHost && a.hasAskingPrice)
                          Text(
                            a.askMet
                                ? 'Ask met · ${formatGhs(a.askingPriceGhs!)}'
                                : 'Your ask · ${formatGhs(a.askingPriceGhs!)} (hidden)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: a.askMet
                                  ? const Color(0xFF81C784)
                                  : HubsomColors.live,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                  _CountdownRing(
                    seconds: secsLeft,
                    ended: !open,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (open && !isHost)
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: HubsomColors.live,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: bidBusy ? null : onQuickBid,
                          child: Text(
                            bidBusy
                                ? 'Bidding…'
                                : 'BID  ${formatGhs(a.nextMinBidGhs)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 52,
                      width: 52,
                      child: OutlinedButton(
                        onPressed: bidBusy ? null : onCustomBid,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Icon(Icons.edit, size: 20),
                      ),
                    ),
                  ],
                )
              else if (isHost && (open || awaiting))
                Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        awaiting
                            ? (a.hasAskingPrice
                                ? 'Ask ${formatGhs(a.askingPriceGhs!)} not met · extend to keep bargaining'
                                : 'Time up · extend to keep bargaining')
                            : (a.askMet
                                ? '$secsLeft s left · ask met at ${formatGhs(a.currentBidGhs)}'
                                : '$secsLeft s left · need ${formatGhs(a.askingPriceGhs ?? a.currentBidGhs)}'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (awaiting || (!a.askMet && open)) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: HubsomColors.gold,
                            foregroundColor: HubsomColors.ink,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: extendBusy ? null : onExtend,
                          icon: const Icon(Icons.more_time),
                          label: Text(
                            extendBusy ? 'Extending…' : 'Extend auction +30s',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ],
                )
              else
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    a.status == 'sold'
                        ? (a.highestBidder == null
                            ? 'Sold · ${formatGhs(a.currentBidGhs)}'
                            : 'Sold · ${a.highestBidder} at ${formatGhs(a.currentBidGhs)}')
                        : a.awaitingExtend
                            ? 'Waiting for host to extend'
                            : (a.highestBidder == null
                                ? 'Auction ended · ${formatGhs(a.currentBidGhs)}'
                                : 'Ended · ${a.highestBidder} at ${formatGhs(a.currentBidGhs)}'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
            ] else if (pinned != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      pinned!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    formatGhs(pinned!.effectivePrice),
                    style: const TextStyle(
                      color: HubsomColors.gold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!isHost && onBuyPinned != null)
                    FilledButton(
                      onPressed: onBuyPinned,
                      style: FilledButton.styleFrom(
                        backgroundColor: HubsomColors.live,
                      ),
                      child: const Text('Buy'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: chatCtrl,
                    style: const TextStyle(color: Colors.white),
                    onSubmitted: (_) => onSendChat(),
                    decoration: InputDecoration(
                      hintText: 'Say something…',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.14),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onSendChat,
                  icon: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CountdownRing extends StatelessWidget {
  const _CountdownRing({required this.seconds, required this.ended});

  final int seconds;
  final bool ended;

  @override
  Widget build(BuildContext context) {
    final urgent = !ended && seconds <= 5;
    return Container(
      width: 58,
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: urgent
            ? HubsomColors.live.withValues(alpha: 0.25)
            : Colors.black.withValues(alpha: 0.45),
        border: Border.all(
          color: ended
              ? Colors.white38
              : (urgent ? HubsomColors.live : HubsomColors.gold),
          width: 3,
        ),
      ),
      child: Text(
        ended ? '0' : '$seconds',
        style: TextStyle(
          color: ended
              ? Colors.white54
              : (urgent ? HubsomColors.live : Colors.white),
          fontWeight: FontWeight.w900,
          fontSize: 22,
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
