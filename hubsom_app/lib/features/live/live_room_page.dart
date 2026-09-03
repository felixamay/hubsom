import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import 'package:uuid/uuid.dart';

import '../../core/auth/require_auth.dart';
import '../../core/providers/core_providers.dart';
import '../../core/services/agora_service.dart';
import '../../core/services/live_webrtc_signal_store.dart';
import '../../core/services/local_store.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../core/utils/money.dart';
import '../../models/cart.dart';
import '../../models/product.dart';
import '../../models/stream.dart';
import '../../widgets/hubsom_image.dart';
import '../../widgets/live_host_camera.dart';
import '../../widgets/live_viewer_video.dart';

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
  bool _hideAuctionCard = false;
  int _likeCount = 0;
  int _shareCount = 0;
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

  String get _viewerPeerId {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user != null && user.id.isNotEmpty) return user.id;
    const key = 'liveViewerPeerId';
    final existing = LocalStore.getString(key);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = 'v_${const Uuid().v4()}';
    unawaited(LocalStore.setString(key, id));
    return id;
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
      if (mounted) setState(() => _shareCount += 1);
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: link));
      if (!mounted) return;
      setState(() => _shareCount += 1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Live link copied — paste to share.')),
      );
    }
  }

  Future<void> _toggleFollow() async {
    final s = stream;
    if (s == null || _isHost || _followBusy) return;
    if (!ensureSignedIn(context, ref, message: 'Sign in to follow this account')) {
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
    setState(() {
      _floating.add(entry);
      _likeCount += 1;
    });
    entry.controller.forward().whenComplete(() {
      entry.controller.dispose();
      if (mounted) setState(() => _floating.removeWhere((e) => e.id == rx.id));
    });
  }

  Future<void> _sendGift() async {
    if (!ensureSignedIn(context, ref, message: 'Sign in to send a gift')) {
      return;
    }
    try {
      await ref.read(liveRepositoryProvider).sendChat(
            widget.streamId,
            'sent a 🎁 gift',
          );
      await _react();
      await _refreshQuiet();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
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
      await LiveWebrtcSignalStore.closeAllForStream(widget.streamId);
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
        _hideAuctionCard = false;
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
                viewerId: _viewerPeerId,
              ),
            ),
            ..._floating.map((f) {
              return AnimatedBuilder(
                animation: f.controller,
                builder: (_, __) {
                  final t = f.controller.value;
                  return Positioned(
                    right: 18 + (MediaQuery.sizeOf(context).width * 0.02),
                    bottom: 110 + (260 * t),
                    child: Opacity(
                      opacity: (1 - t).clamp(0, 1),
                      child: Transform.scale(
                        scale: 0.85 + (0.35 * (1 - t)),
                        child: Icon(
                          Icons.favorite,
                          color: Colors.pinkAccent.withValues(alpha: 0.95),
                          size: 34,
                          shadows: const [
                            Shadow(blurRadius: 8, color: Colors.black45),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
            // TikTok-style top chrome: host + Follow | viewers + close
            Positioned(
              left: 10,
              top: 6,
              right: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: _HostHeaderChip(
                          name: _hostName,
                          avatar: s.hosts.isNotEmpty ? s.hosts.first.avatar : '',
                          likes: _likeCount,
                          following: _following,
                          followBusy: _followBusy,
                          showFollow: !_isHost,
                          onFollow: _toggleFollow,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _ViewerCountPill(count: s.viewerCount),
                      IconButton(
                        onPressed: () {
                          if (_isHost) {
                            _endLive();
                          } else {
                            context.go('/live');
                          }
                        },
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ScaleTransition(
                        scale: Tween(begin: 0.96, end: 1.04).animate(_pulse),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: HubsomColors.live,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _GlassPill(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.shopping_bag,
                              size: 14,
                              color: Color(0xFFFFC107),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Shopping No.${bag.isEmpty ? 0 : bag.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isHost) ...[
                        const SizedBox(width: 6),
                        _GlassPill(
                          onTap: () => setState(() => _micOn = !_micOn),
                          child: Icon(
                            _micOn ? Icons.mic : Icons.mic_off,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 4),
                        _GlassPill(
                          onTap: () => setState(() => _camOn = !_camOn),
                          child: Icon(
                            _camOn ? Icons.videocam : Icons.videocam_off,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 4),
                        _GlassPill(
                          onTap: () {
                            final ids = bag.map((p) => p.id).join(',');
                            final q = ids.isEmpty
                                ? ''
                                : '?productIds=${Uri.encodeComponent(ids)}';
                            context.push('/videos/upload$q');
                          },
                          child: const Text(
                            'Add video',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (!_shopOpen)
              Positioned(
                left: 10,
                right: MediaQuery.sizeOf(context).width * 0.22,
                bottom: (!_hideAuctionCard &&
                        (s.auction != null || pinned != null))
                    ? (_isHost ? 268 : 228)
                    : 78,
                child: SizedBox(
                  height: 150,
                  child: ListView(
                    reverse: true,
                    children: chat.take(24).map((m) {
                      final isBid =
                          m.text.contains('Bid ') && m.text.contains('GHS');
                      final isGift = m.text.contains('🎁');
                      final isFollow =
                          m.text.toLowerCase().contains('following');
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.38),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${m.displayName} ',
                                    style: TextStyle(
                                      color: isBid
                                          ? HubsomColors.gold
                                          : (isGift
                                              ? const Color(0xFFFF8A80)
                                              : Colors.white),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                  TextSpan(
                                    text: m.text,
                                    style: TextStyle(
                                      color: isFollow
                                          ? Colors.white70
                                          : Colors.white,
                                      fontWeight: isBid
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
                  hideAuctionCard: _hideAuctionCard,
                  bagCount: bag.length,
                  shareCount: _shareCount,
                  chatCtrl: _chatCtrl,
                  onQuickBid: _bidQuick,
                  onCustomBid: _bidCustom,
                  onExtend: _extendAuction,
                  onBuyPinned: pinned == null ? null : () => _buy(pinned!),
                  onSendChat: _sendChat,
                  onOpenShop: _openShop,
                  onReact: _react,
                  onGift: _sendGift,
                  onShare: _shareShow,
                  onDismissAuction: () =>
                      setState(() => _hideAuctionCard = true),
                  onShowAuction: () =>
                      setState(() => _hideAuctionCard = false),
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
                                  'Products only — use Add video on the live bar for clips',
                                )
                              : null,
                          trailing: IconButton(
                            onPressed: () => setState(() => _shopOpen = false),
                            icon: const Icon(Icons.close),
                          ),
                        ),
                        if (_isHost)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () {
                                  final returnTo = Uri.encodeComponent(
                                    '/live/${widget.streamId}?host=1',
                                  );
                                  context.push(
                                    '/seller/products/new?returnTo=$returnTo&addToLive=${widget.streamId}',
                                  );
                                },
                                icon: const Icon(Icons.add_box_outlined),
                                label: const Text('Create product for this live'),
                              ),
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
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
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
                                    '${formatGhs(p.effectivePrice)} · ${p.stock} for sale',
                                  ),
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
                                          onPressed: p.stock <= 0
                                              ? null
                                              : () => _buy(p),
                                          child: Text(
                                            p.stock <= 0 ? 'Sold out' : 'Buy',
                                          ),
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
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _catalog.isEmpty
                                              ? 'No products yet. Create a real product with photos and quantity, then it joins this live show.'
                                              : 'All your products are already in this live show.',
                                        ),
                                        if (_catalog.isEmpty) ...[
                                          const SizedBox(height: 12),
                                          OutlinedButton.icon(
                                            onPressed: () {
                                              final returnTo =
                                                  Uri.encodeComponent(
                                                '/live/${widget.streamId}?host=1',
                                              );
                                              context.push(
                                                '/seller/products/new?returnTo=$returnTo&addToLive=${widget.streamId}',
                                              );
                                            },
                                            icon: const Icon(
                                              Icons.add_box_outlined,
                                            ),
                                            label: const Text(
                                              'Create product now',
                                            ),
                                          ),
                                        ],
                                      ],
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
                                            '${formatGhs(p.effectivePrice)} · ${p.stock} for sale',
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
    required this.viewerId,
  });

  final LiveStream stream;
  final bool camOn;
  final bool micOn;
  final AnimationController pulse;
  final bool isHost;
  final String hostName;
  final String viewerId;

  @override
  Widget build(BuildContext context) {
    if (isHost) {
      return LiveHostCamera(
        enabled: camOn,
        micOn: micOn,
        hostName: hostName,
        streamId: stream.id,
      );
    }

    return LiveViewerVideo(
      streamId: stream.id,
      viewerId: viewerId,
      hostName: hostName,
      pulse: pulse,
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
    required this.hideAuctionCard,
    required this.bagCount,
    required this.shareCount,
    required this.chatCtrl,
    required this.onQuickBid,
    required this.onCustomBid,
    required this.onExtend,
    required this.onBuyPinned,
    required this.onSendChat,
    required this.onOpenShop,
    required this.onReact,
    required this.onGift,
    required this.onShare,
    required this.onDismissAuction,
    required this.onShowAuction,
  });

  final LiveAuction? auction;
  final Product? pinned;
  final bool isHost;
  final bool bidBusy;
  final bool extendBusy;
  final bool hideAuctionCard;
  final int bagCount;
  final int shareCount;
  final TextEditingController chatCtrl;
  final VoidCallback onQuickBid;
  final VoidCallback onCustomBid;
  final VoidCallback onExtend;
  final VoidCallback? onBuyPinned;
  final VoidCallback onSendChat;
  final VoidCallback onOpenShop;
  final VoidCallback onReact;
  final VoidCallback onGift;
  final VoidCallback onShare;
  final VoidCallback onDismissAuction;
  final VoidCallback onShowAuction;

  @override
  Widget build(BuildContext context) {
    final a = auction;
    final left = a?.timeLeft ?? Duration.zero;
    final secsLeft = left.inSeconds.clamp(0, 30);
    final open = a?.isOpen == true;
    final awaiting = a?.awaitingExtend == true;
    final showCard = !hideAuctionCard && (a != null || pinned != null);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.35),
            Colors.black.withValues(alpha: 0.78),
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hideAuctionCard && (a != null || pinned != null))
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onShowAuction,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white24,
                    ),
                    icon: const Icon(Icons.gavel, size: 16),
                    label: const Text('Show deal'),
                  ),
                ),
              if (showCard && a != null)
                _SleekAuctionCard(
                  auction: a,
                  pinned: pinned,
                  isHost: isHost,
                  secsLeft: secsLeft,
                  open: open,
                  awaiting: awaiting,
                  bidBusy: bidBusy,
                  extendBusy: extendBusy,
                  onQuickBid: onQuickBid,
                  onCustomBid: onCustomBid,
                  onExtend: onExtend,
                  onDismiss: onDismissAuction,
                )
              else if (showCard && pinned != null)
                _SleekBuyCard(
                  product: pinned!,
                  isHost: isHost,
                  onBuy: onBuyPinned,
                  onDismiss: onDismissAuction,
                ),
              if (isHost && a != null && (open || awaiting)) ...[
                const SizedBox(height: 8),
                _HostBidFeed(auction: a),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  InkWell(
                    onTap: onOpenShop,
                    borderRadius: BorderRadius.circular(12),
                    child: Badge(
                      isLabelVisible: bagCount > 0,
                      label: Text('$bagCount'),
                      backgroundColor: const Color(0xFFFF6D00),
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6D00),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.shopping_bag,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: chatCtrl,
                      style: const TextStyle(color: Colors.white),
                      onSubmitted: (_) => onSendChat(),
                      decoration: InputDecoration(
                        hintText: 'Type...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.16),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Like',
                    onPressed: onReact,
                    icon: const Icon(Icons.favorite, color: Colors.pinkAccent),
                  ),
                  IconButton(
                    tooltip: 'Gift',
                    onPressed: onGift,
                    icon: const Icon(
                      Icons.card_giftcard,
                      color: Color(0xFFFF8A80),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Share',
                        onPressed: onShare,
                        icon: const Icon(Icons.reply, color: Colors.white),
                      ),
                      if (shareCount > 0)
                        Text(
                          '$shareCount',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SleekAuctionCard extends StatelessWidget {
  const _SleekAuctionCard({
    required this.auction,
    required this.pinned,
    required this.isHost,
    required this.secsLeft,
    required this.open,
    required this.awaiting,
    required this.bidBusy,
    required this.extendBusy,
    required this.onQuickBid,
    required this.onCustomBid,
    required this.onExtend,
    required this.onDismiss,
  });

  final LiveAuction auction;
  final Product? pinned;
  final bool isHost;
  final int secsLeft;
  final bool open;
  final bool awaiting;
  final bool bidBusy;
  final bool extendBusy;
  final VoidCallback onQuickBid;
  final VoidCallback onCustomBid;
  final VoidCallback onExtend;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final a = auction;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C4DFF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer, size: 14, color: Colors.white),
                    const SizedBox(width: 3),
                    Text(
                      open ? '${secsLeft}s' : '0s',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatGhs(a.currentBidGhs),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 26,
                        height: 1.05,
                        color: Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      a.highestBidder == null
                          ? 'Be the first to bid'
                          : '${a.highestBidder} is winning',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDismiss,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 18, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            pinned?.name ?? 'Live auction',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: Color(0xFF222222),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            pinned == null
                ? 'Huber delivery across Ghana · Buyer protected'
                : '${pinned!.stock} for sale · Huber shipping · Buyer protected',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Color(0xFF777777)),
          ),
          if (isHost && a.hasAskingPrice) ...[
            const SizedBox(height: 4),
            Text(
              a.askMet
                  ? 'Ask met · ${formatGhs(a.askingPriceGhs!)}'
                  : 'Your ask · ${formatGhs(a.askingPriceGhs!)} (hidden)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: a.askMet ? HubsomColors.forest : HubsomColors.live,
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (open && !isHost)
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: bidBusy ? null : onCustomBid,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF111111),
                        side: const BorderSide(color: Color(0xFFDDDDDD)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      child: const Text(
                        'Custom',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 44,
                    child: FilledButton(
                      onPressed: bidBusy ? null : onQuickBid,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE91E63),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      child: Text(
                        bidBusy
                            ? 'Bidding…'
                            : 'Bid ${formatGhs(a.nextMinBidGhs)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          else if (isHost && (open || awaiting))
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton.icon(
                onPressed: extendBusy ? null : onExtend,
                style: FilledButton.styleFrom(
                  backgroundColor: HubsomColors.gold,
                  foregroundColor: HubsomColors.ink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                icon: const Icon(Icons.more_time),
                label: Text(
                  extendBusy ? 'Extending…' : 'Extend auction +30s',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            )
          else
            Text(
              a.status == 'sold'
                  ? (a.highestBidder == null
                      ? 'Sold · ${formatGhs(a.currentBidGhs)}'
                      : 'Sold · ${a.highestBidder} at ${formatGhs(a.currentBidGhs)}')
                  : awaiting
                      ? 'Waiting for host to extend'
                      : (a.highestBidder == null
                          ? 'Auction ended · ${formatGhs(a.currentBidGhs)}'
                          : 'Ended · ${a.highestBidder} at ${formatGhs(a.currentBidGhs)}'),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF333333),
              ),
            ),
        ],
      ),
    );
  }
}

class _SleekBuyCard extends StatelessWidget {
  const _SleekBuyCard({
    required this.product,
    required this.isHost,
    required this.onBuy,
    required this.onDismiss,
  });

  final Product product;
  final bool isHost;
  final VoidCallback? onBuy;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 52,
              height: 52,
              child: product.images.isNotEmpty
                  ? HubsomImage(
                      url: product.images.first,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: HubsomColors.mist,
                      child: const Icon(Icons.shopping_bag),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  formatGhs(product.effectivePrice),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                Text(
                  '${product.stock} for sale · Huber shipping',
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
          if (!isHost && onBuy != null)
            FilledButton(
              onPressed: product.stock <= 0 ? null : onBuy,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE91E63),
              ),
              child: Text(product.stock <= 0 ? 'Sold out' : 'Buy'),
            ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }
}

class _HostHeaderChip extends StatelessWidget {
  const _HostHeaderChip({
    required this.name,
    required this.avatar,
    required this.likes,
    required this.following,
    required this.followBusy,
    required this.showFollow,
    required this.onFollow,
  });

  final String name;
  final String avatar;
  final int likes;
  final bool following;
  final bool followBusy;
  final bool showFollow;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'H';
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 6, 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: HubsomColors.forest,
            backgroundImage:
                avatar.trim().isNotEmpty ? NetworkImage(avatar) : null,
            child: avatar.trim().isNotEmpty
                ? null
                : Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.favorite, size: 10, color: Colors.white70),
                    const SizedBox(width: 2),
                    Text(
                      likes > 0 ? '$likes' : '0',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (showFollow) ...[
            const SizedBox(width: 6),
            Material(
              color: following ? Colors.white24 : HubsomColors.live,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: followBusy ? null : onFollow,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Text(
                    following ? 'Following' : '+ Follow',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ViewerCountPill extends StatelessWidget {
  const _ViewerCountPill({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
    if (onTap == null) return pill;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: pill,
    );
  }
}

class _HostBidFeed extends StatelessWidget {
  const _HostBidFeed({required this.auction});

  final LiveAuction auction;

  @override
  Widget build(BuildContext context) {
    final bids = auction.recentBids;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_alt_outlined, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                bids.isEmpty
                    ? 'Waiting for bids…'
                    : 'Who\'s bidding · ${auction.bidderCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              if (auction.highestBidder != null)
                Text(
                  'Lead · ${auction.highestBidder}',
                  style: const TextStyle(
                    color: HubsomColors.gold,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          if (bids.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Shopper names appear here as soon as they bid.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 11,
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 92,
              child: ListView.separated(
                itemCount: bids.length.clamp(0, 8),
                separatorBuilder: (_, __) => Divider(
                  height: 10,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
                itemBuilder: (context, i) {
                  final bid = bids[i];
                  final leading = i == 0;
                  final initial = bid.bidderName.isNotEmpty
                      ? bid.bidderName.substring(0, 1).toUpperCase()
                      : '?';
                  return Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: leading
                            ? HubsomColors.gold
                            : HubsomColors.forest,
                        child: Text(
                          initial,
                          style: TextStyle(
                            color: leading ? HubsomColors.ink : Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          bid.bidderName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight:
                                leading ? FontWeight.w800 : FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Text(
                        formatGhs(bid.amountGhs),
                        style: TextStyle(
                          color: leading ? HubsomColors.gold : Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                      if (leading) ...[
                        const SizedBox(width: 6),
                        const Text(
                          'LEAD',
                          style: TextStyle(
                            color: HubsomColors.gold,
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ],
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
