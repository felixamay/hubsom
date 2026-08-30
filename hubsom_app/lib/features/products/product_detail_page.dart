import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/auth/require_auth.dart';
import '../../core/providers/core_providers.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../core/utils/money.dart';
import '../../models/cart.dart';
import '../../models/message.dart';
import '../../models/product.dart';
import '../../models/product_social.dart';
import '../../models/seller.dart';
import '../../widgets/hubsom_image.dart';
import '../../widgets/product_demo_video_player.dart';

class ProductDetailPage extends ConsumerStatefulWidget {
  const ProductDetailPage({super.key, required this.productId});
  final String productId;

  @override
  ConsumerState<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends ConsumerState<ProductDetailPage> {
  Product? _product;
  Seller? _seller;
  List<ProductComment> _comments = const [];
  bool _loading = true;
  String? _error;
  bool _saved = false;
  bool _liked = false;
  int _likes = 0;
  bool _following = false;
  bool _followBusy = false;
  bool _busy = false;
  int _mediaIndex = 0;
  final _commentCtrl = TextEditingController();
  final _commentsKey = GlobalKey();
  final _pageCtrl = PageController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final catalog = ref.read(catalogRepositoryProvider);
      final product = await catalog.getProduct(widget.productId);
      if (product == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Product not found';
        });
        return;
      }
      final comments = await catalog.listComments(product.id);
      Seller? seller;
      try {
        seller = await catalog.getSeller(product.sellerId);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _product = product;
        _seller = seller;
        _comments = comments;
        _saved = catalog.isSaved(product.id);
        _liked = catalog.isLiked(product.id);
        _likes = catalog.likeCount(product.id);
        _following = catalog.isFollowingSeller(product.sellerId);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  String get _productLink {
    final p = _product;
    if (p == null) return Uri.base.toString();
    return Uri.base
        .replace(path: '/products/${p.id}', query: '', fragment: '')
        .toString();
  }

  Future<void> _toggleSave() async {
    if (!ensureSignedIn(context, ref, message: 'Sign in to save products')) {
      return;
    }
    final saved =
        await ref.read(catalogRepositoryProvider).toggleSave(widget.productId);
    ref.invalidate(authStateProvider);
    if (!mounted) return;
    setState(() => _saved = saved);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(saved ? 'Saved to wishlist' : 'Removed from saved')),
    );
  }

  Future<void> _toggleLike() async {
    if (!ensureSignedIn(context, ref, message: 'Sign in to like products')) {
      return;
    }
    final liked =
        await ref.read(catalogRepositoryProvider).toggleLike(widget.productId);
    ref.invalidate(authStateProvider);
    if (!mounted) return;
    setState(() {
      _liked = liked;
      _likes = ref.read(catalogRepositoryProvider).likeCount(widget.productId);
    });
  }

  Future<void> _toggleFollow() async {
    final product = _product;
    if (product == null) return;
    if (!ensureSignedIn(context, ref, message: 'Sign in to follow sellers')) {
      return;
    }
    setState(() => _followBusy = true);
    try {
      final catalog = ref.read(catalogRepositoryProvider);
      final next = _following
          ? await catalog.unfollowSeller(product.sellerId)
          : await catalog.followSeller(product.sellerId);
      ref.invalidate(authStateProvider);
      if (!mounted) return;
      setState(() => _following = next);
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  void _scrollToComments() {
    final ctx = _commentsKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  bool get _isOwner {
    final user = ref.read(authStateProvider).valueOrNull;
    final product = _product;
    if (user == null || product == null) return false;
    if (user.sellerId != null && user.sellerId == product.sellerId) return true;
    return _seller?.ownerUserId == user.id;
  }

  Future<void> _confirmDeleteProduct() async {
    final product = _product;
    if (product == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text(
          '“${product.name}” will be removed from your store and catalog.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(sellerRepositoryProvider).deleteProduct(product.id);
      ref.invalidate(productsProvider((category: null, q: null)));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted ${product.name}')),
      );
      context.go('/seller/products');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _submitComment() async {
    if (!ensureSignedIn(context, ref, message: 'Sign in to comment')) return;
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _busy = true);
    try {
      final comment = await ref
          .read(catalogRepositoryProvider)
          .addComment(widget.productId, text);
      _commentCtrl.clear();
      if (!mounted) return;
      setState(() {
        _comments = [comment, ..._comments];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareSheet() async {
    final product = _product;
    if (product == null) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.ios_share),
              title: const Text('Share via apps'),
              subtitle: const Text('WhatsApp, SMS, and more'),
              onTap: () async {
                Navigator.pop(ctx);
                final text =
                    'Check out ${product.name} on Hubsom · ${formatGhs(product.effectivePrice)}\n$_productLink';
                try {
                  await Share.share(text, subject: product.name);
                } catch (_) {
                  await Clipboard.setData(ClipboardData(text: _productLink));
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Link copied')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.dynamic_feed_outlined),
              title: const Text('Share to your timeline'),
              subtitle: const Text('Post this product for Hubsom shoppers'),
              onTap: () async {
                Navigator.pop(ctx);
                if (!ensureSignedIn(
                  context,
                  ref,
                  message: 'Sign in to share to your timeline',
                )) {
                  return;
                }
                try {
                  await ref
                      .read(catalogRepositoryProvider)
                      .shareToTimeline(product.id);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Posted to your timeline'),
                      action: SnackBarAction(
                        label: 'View',
                        onPressed: () => context.push('/timeline'),
                      ),
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('$e')));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('Share with people'),
              subtitle: const Text('Send the product link in a message'),
              onTap: () {
                Navigator.pop(ctx);
                _shareToPeople();
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Copy link'),
              onTap: () async {
                Navigator.pop(ctx);
                await Clipboard.setData(ClipboardData(text: _productLink));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Product link copied')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareToPeople() async {
    if (!ensureSignedIn(context, ref, message: 'Sign in to message people')) {
      return;
    }
    final product = _product!;
    final text =
        'Check out ${product.name} on Hubsom: $_productLink';

    List<ConversationPreview> conversations = const [];
    try {
      conversations =
          await ref.read(messageRepositoryProvider).listConversations();
    } catch (_) {}

    final following =
        ref.read(authStateProvider).valueOrNull?.followingSellerIds ??
            const <String>[];
    final sellers = <Map<String, String>>[];
    for (final id in following) {
      final s = await ref.read(catalogRepositoryProvider).getSeller(id);
      if (s != null) sellers.add({'id': s.id, 'name': s.name});
    }

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        if (conversations.isEmpty && sellers.isEmpty) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Share with people',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'No chats yet. Share the link with friends, or follow sellers to message them.',
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await Share.share(text, subject: product.name);
                    },
                    child: const Text('Share link instead'),
                  ),
                ],
              ),
            ),
          );
        }
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                title: Text(
                  'Send product to…',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              ...conversations.map(
                (c) => ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(c.name),
                  subtitle: Text(c.lastMessage, maxLines: 1),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      await ref
                          .read(messageRepositoryProvider)
                          .send(c.userId, text);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Sent to ${c.name}')),
                      );
                    } catch (_) {
                      await Clipboard.setData(ClipboardData(text: text));
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Could not send chat — product link copied instead',
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
              ...sellers.map(
                (s) => ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.storefront)),
                  title: Text(s['name']!),
                  subtitle: const Text('Following'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      await ref
                          .read(messageRepositoryProvider)
                          .send(s['id']!, text);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Sent to ${s['name']}')),
                      );
                    } catch (_) {
                      await Clipboard.setData(ClipboardData(text: text));
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Could not send chat — product link copied instead',
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<_MediaSlide> _slidesFor(Product product) {
    final slides = <_MediaSlide>[];
    if (product.showsDemoVideo) {
      slides.add(const _MediaSlide.video());
    }
    for (final url in product.images) {
      if (url.trim().isEmpty) continue;
      slides.add(_MediaSlide.image(url));
    }
    if (slides.isEmpty) {
      slides.add(const _MediaSlide.placeholder());
    }
    return slides;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _product == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(_error ?? 'Product not found')),
      );
    }
    final product = _product!;
    final image = product.images.isNotEmpty ? product.images.first : null;
    final slides = _slidesFor(product);
    final mediaHeight =
        (MediaQuery.sizeOf(context).height * 0.62).clamp(360.0, 640.0);

    return Scaffold(
      backgroundColor: Colors.white,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          SizedBox(
            height: mediaHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  controller: _pageCtrl,
                  itemCount: slides.length,
                  onPageChanged: (i) => setState(() => _mediaIndex = i),
                  itemBuilder: (context, i) {
                    final slide = slides[i];
                    switch (slide.kind) {
                      case _MediaKind.video:
                        return ColoredBox(
                          color: Colors.black,
                          child: ProductDemoVideoPlayer(
                            productId: product.id,
                            remoteUrl: product.demoVideoUrl,
                            expand: true,
                            autoplay: true,
                            borderRadius: 0,
                          ),
                        );
                      case _MediaKind.image:
                        return ColoredBox(
                          color: const Color(0xFF0B1F17),
                          child: HubsomImage(
                            url: slide.url,
                            fit: BoxFit.cover,
                            placeholder: Container(
                              color: HubsomColors.mist,
                              child: const Icon(
                                Icons.image,
                                size: 64,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                        );
                      case _MediaKind.placeholder:
                        return Container(
                          color: const Color(0xFF0B1F17),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.image,
                            size: 64,
                            color: Colors.white54,
                          ),
                        );
                    }
                  },
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x99000000), Color(0x00000000)],
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go('/');
                              }
                            },
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          if (_isOwner)
                            PopupMenuButton<String>(
                              icon: const Icon(
                                Icons.more_vert,
                                color: Colors.white,
                              ),
                              onSelected: (value) async {
                                if (value == 'edit') {
                                  await context.push(
                                    '/seller/products/${product.id}/edit',
                                  );
                                  if (mounted) _load();
                                } else if (value == 'delete') {
                                  await _confirmDeleteProduct();
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit product'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete product'),
                                ),
                              ],
                            ),
                          if (slides.length > 1)
                            Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: Text(
                                '${_mediaIndex + 1}/${slides.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 78,
                  bottom: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (slides.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              for (var i = 0; i < slides.length; i++)
                                Container(
                                  width: i == _mediaIndex ? 16 : 6,
                                  height: 6,
                                  margin: const EdgeInsets.only(right: 4),
                                  decoration: BoxDecoration(
                                    color: i == _mediaIndex
                                        ? Colors.white
                                        : Colors.white38,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          height: 1.15,
                          shadows: [
                            Shadow(blurRadius: 8, color: Colors.black54),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        formatGhs(product.effectivePrice),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          shadows: [
                            Shadow(blurRadius: 8, color: Colors.black54),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 24,
                  child: _ActionRail(
                    seller: _seller,
                    following: _following,
                    followBusy: _followBusy,
                    liked: _liked,
                    likes: _likes,
                    comments: _comments.length,
                    saved: _saved,
                    onFollow: _toggleFollow,
                    onLike: _toggleLike,
                    onComment: _scrollToComments,
                    onShare: _shareSheet,
                    onSave: _toggleSave,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (product.compareAtGhs != null)
                  Text(
                    formatGhs(product.compareAtGhs!),
                    style: const TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: Colors.grey,
                    ),
                  ),
                Text('Stock: ${product.stock}'),
                const SizedBox(height: 10),
                Text(product.description),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final t in product.tags)
                      Chip(
                        label: Text(t),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                KeyedSubtree(
                  key: _commentsKey,
                  child: Text(
                    'Comments',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Say something about this product…',
                        ),
                        minLines: 1,
                        maxLines: 3,
                        onSubmitted: (_) => _submitComment(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _busy ? null : _submitComment,
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_comments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('No comments yet — be the first'),
                  )
                else
                  ..._comments.map(
                    (c) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        c.userName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(c.text),
                    ),
                  ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    await ref.read(cartProvider.notifier).add(
                          CartItem(
                            productId: product.id,
                            quantity: 1,
                            source: 'buy-now',
                            name: product.name,
                            priceGhs: product.effectivePrice,
                            image: image,
                            category: product.category,
                          ),
                        );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Added to cart')),
                      );
                    }
                  },
                  child: const Text('Add to cart'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    if (!ensureSignedIn(
                      context,
                      ref,
                      message: 'Sign in to buy',
                    )) {
                      return;
                    }
                    await ref.read(cartProvider.notifier).add(
                          CartItem(
                            productId: product.id,
                            quantity: 1,
                            source: 'buy-now',
                            name: product.name,
                            priceGhs: product.effectivePrice,
                            image: image,
                            category: product.category,
                          ),
                        );
                    if (context.mounted) context.push('/checkout');
                  },
                  child: const Text('Buy now'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _MediaKind { video, image, placeholder }

class _MediaSlide {
  const _MediaSlide._(this.kind, this.url);
  const _MediaSlide.video() : this._(_MediaKind.video, null);
  const _MediaSlide.image(String url) : this._(_MediaKind.image, url);
  const _MediaSlide.placeholder() : this._(_MediaKind.placeholder, null);

  final _MediaKind kind;
  final String? url;
}

class _ActionRail extends StatelessWidget {
  const _ActionRail({
    required this.seller,
    required this.following,
    required this.followBusy,
    required this.liked,
    required this.likes,
    required this.comments,
    required this.saved,
    required this.onFollow,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onSave,
  });

  final Seller? seller;
  final bool following;
  final bool followBusy;
  final bool liked;
  final int likes;
  final int comments;
  final bool saved;
  final VoidCallback onFollow;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final initial = (seller?.name.isNotEmpty == true)
        ? seller!.name.substring(0, 1).toUpperCase()
        : 'S';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: HubsomColors.forest,
                  backgroundImage: (seller?.avatar.isNotEmpty == true)
                      ? NetworkImage(seller!.avatar)
                      : null,
                  child: (seller?.avatar.isNotEmpty == true)
                      ? null
                      : Text(
                          initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
                Positioned(
                  bottom: -10,
                  child: Material(
                    color: following ? Colors.white24 : HubsomColors.live,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: followBusy ? null : onFollow,
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: Icon(
                          following ? Icons.check : Icons.add,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              following ? 'Following' : 'Follow',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _RailAction(
          icon: liked ? Icons.favorite : Icons.favorite_border,
          label: likes > 0 ? '$likes' : 'Like',
          color: liked ? HubsomColors.live : Colors.white,
          onTap: onLike,
        ),
        const SizedBox(height: 16),
        _RailAction(
          icon: Icons.mode_comment_outlined,
          label: comments > 0 ? '$comments' : 'Comment',
          onTap: onComment,
        ),
        const SizedBox(height: 16),
        _RailAction(
          icon: Icons.ios_share,
          label: 'Share',
          onTap: onShare,
        ),
        const SizedBox(height: 16),
        _RailAction(
          icon: saved ? Icons.bookmark : Icons.bookmark_border,
          label: saved ? 'Saved' : 'Save',
          color: saved ? HubsomColors.gold : Colors.white,
          onTap: onSave,
        ),
      ],
    );
  }
}

class _RailAction extends StatelessWidget {
  const _RailAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
