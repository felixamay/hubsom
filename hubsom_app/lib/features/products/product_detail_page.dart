import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/auth/require_auth.dart';
import '../../core/providers/core_providers.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../core/utils/money.dart';
import '../../models/message.dart';
import '../../models/product.dart';
import '../../models/product_social.dart';
import '../../models/review.dart';
import '../../models/seller.dart';
import '../../widgets/commerce_cta_bar.dart';
import '../../widgets/hubsom_image.dart';
import '../../widgets/product_card.dart';

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
  List<ProductReview> _reviews = const [];
  List<Product> _suggested = const [];
  bool _loading = true;
  String? _error;
  bool _saved = false;
  bool _liked = false;
  int _likes = 0;
  bool _following = false;
  bool _followBusy = false;
  int _mediaIndex = 0;
  int _reviewRating = 5;
  final _reviewCtrl = TextEditingController();
  bool _reviewBusy = false;
  final _pageCtrl = PageController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _reviewCtrl.dispose();
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
      final reviews = await catalog.listReviews(product.id);
      final suggestedRaw = await catalog.listProducts(
        category: product.category,
        limit: 12,
      );
      final suggested = suggestedRaw
          .where((p) => p.id != product.id)
          .take(6)
          .toList();
      Seller? seller;
      try {
        seller = await catalog.getSeller(product.sellerId);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _product = product;
        _seller = seller;
        _comments = comments;
        _reviews = reviews;
        _suggested = suggested;
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
    if (!ensureSignedIn(context, ref, message: 'Sign in to follow this account')) {
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

  void _openComments() {
    context.push('/products/${widget.productId}/comments');
  }

  Future<void> _submitReview() async {
    if (!ensureSignedIn(context, ref, message: 'Sign in to leave a review')) {
      return;
    }
    setState(() => _reviewBusy = true);
    try {
      final review = await ref.read(catalogRepositoryProvider).submitReview(
            widget.productId,
            rating: _reviewRating,
            comment: _reviewCtrl.text.trim(),
          );
      _reviewCtrl.clear();
      if (!mounted) return;
      setState(() {
        _reviews = [review, ..._reviews.where((r) => r.id != review.id)];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review posted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _reviewBusy = false);
    }
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
    final slides = _slidesFor(product);
    final mediaHeight =
        (MediaQuery.sizeOf(context).width * 0.95).clamp(260.0, 420.0);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          product.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_isOwner)
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'edit') {
                  await context.push('/seller/products/${product.id}/edit');
                  if (mounted) _load();
                } else if (value == 'delete') {
                  await _confirmDeleteProduct();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit product')),
                PopupMenuItem(value: 'delete', child: Text('Delete product')),
              ],
            ),
          IconButton(
            tooltip: 'Share',
            onPressed: _shareSheet,
            icon: const Icon(Icons.ios_share_outlined),
          ),
        ],
      ),
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
                      case _MediaKind.image:
                        return ColoredBox(
                          color: HubsomColors.mist,
                          child: HubsomImage(
                            url: slide.url,
                            fit: BoxFit.cover,
                            placeholder: Container(
                              color: HubsomColors.mist,
                              child: const Icon(
                                Icons.image,
                                size: 64,
                                color: Colors.black26,
                              ),
                            ),
                          ),
                        );
                      case _MediaKind.placeholder:
                        return Container(
                          color: HubsomColors.mist,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.image,
                            size: 64,
                            color: Colors.black26,
                          ),
                        );
                    }
                  },
                ),
                if (slides.length > 1)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < slides.length; i++)
                          Container(
                            width: i == _mediaIndex ? 16 : 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: i == _mediaIndex
                                  ? HubsomColors.forest
                                  : Colors.white70,
                              borderRadius: BorderRadius.circular(99),
                              boxShadow: const [
                                BoxShadow(
                                  blurRadius: 2,
                                  color: Colors.black26,
                                ),
                              ],
                            ),
                          ),
                      ],
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
                Text(
                  product.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                if (product.isAuctionLot) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Auction lot · hidden from store. Sellers tap it on live to start selling.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  formatGhs(product.effectivePrice),
                  style: const TextStyle(
                    color: HubsomColors.forest,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
                if (product.compareAtGhs != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    formatGhs(product.compareAtGhs!),
                    style: const TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: Colors.grey,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      product.stock <= 0
                          ? 'Sold out'
                          : '${product.stock} for sale',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: product.stock <= 0
                            ? Theme.of(context).colorScheme.error
                            : HubsomColors.forest,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.star, size: 16, color: HubsomColors.gold),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        product.reviewCount > 0 || _reviews.isNotEmpty
                            ? '${(product.rating > 0 ? product.rating : (_reviews.isEmpty ? 0 : _reviews.map((r) => r.rating).reduce((a, b) => a + b) / _reviews.length)).toStringAsFixed(1)} · ${_reviews.isNotEmpty ? _reviews.length : product.reviewCount} reviews'
                            : 'No reviews yet',
                      ),
                    ),
                  ],
                ),
                if (_seller != null) ...[
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: HubsomColors.mint,
                      child: Text(
                        _seller!.name.isNotEmpty
                            ? _seller!.name[0].toUpperCase()
                            : 'S',
                        style: const TextStyle(
                          color: HubsomColors.forest,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    title: Text(
                      _seller!.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      _seller!.displayLocation.isEmpty
                          ? '${_seller!.city}, ${_seller!.region}'
                          : _seller!.displayLocation,
                    ),
                    trailing: FilledButton.tonal(
                      onPressed: _followBusy ? null : _toggleFollow,
                      child: Text(_following ? 'Following' : 'Follow'),
                    ),
                    onTap: () => context.push('/stores/${_seller!.slug}'),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      avatar: Icon(
                        _liked ? Icons.favorite : Icons.favorite_border,
                        size: 18,
                        color: _liked ? HubsomColors.live : null,
                      ),
                      label: Text(_likes > 0 ? '$_likes' : 'Like'),
                      onPressed: _toggleLike,
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.mode_comment_outlined, size: 18),
                      label: Text(
                        _comments.isEmpty
                            ? 'Comments'
                            : 'Comments (${_comments.length})',
                      ),
                      onPressed: _openComments,
                    ),
                    ActionChip(
                      avatar: Icon(
                        _saved ? Icons.bookmark : Icons.bookmark_border,
                        size: 18,
                      ),
                      label: Text(_saved ? 'Saved' : 'Save'),
                      onPressed: _toggleSave,
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.ios_share_outlined, size: 18),
                      label: const Text('Share'),
                      onPressed: _shareSheet,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Details',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  product.description.trim().isEmpty
                      ? 'No extra details from the seller yet.'
                      : product.description,
                ),
                if (product.tags.isNotEmpty) ...[
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
                ],
                const SizedBox(height: 20),
                _SectionCard(
                  icon: Icons.local_shipping_outlined,
                  title: 'Shipping',
                  child: Text(
                    _seller == null
                        ? 'Delivered across Ghana with Hubsom Huber riders. Typical Accra delivery 1–2 days; other regions 2–5 days after dispatch.'
                        : 'Ships from ${_seller!.city}, ${_seller!.region}. Hubsom Huber riders deliver across Ghana — Accra usually 1–2 days, other regions 2–5 days after the seller ships.',
                  ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  icon: Icons.verified_user_outlined,
                  title: 'Guarantees',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('• Hubsom buyer protection on paid orders'),
                      SizedBox(height: 4),
                      Text(
                        '• Contact the seller within 7 days for damaged or wrong items',
                      ),
                      SizedBox(height: 4),
                      Text(
                        '• Secure checkout — pay before Huber delivery starts',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Reviews',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var i = 1; i <= 5; i++)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: _reviewBusy
                            ? null
                            : () => setState(() => _reviewRating = i),
                        icon: Icon(
                          i <= _reviewRating ? Icons.star : Icons.star_border,
                          color: HubsomColors.gold,
                        ),
                      ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _reviewCtrl,
                        enabled: !_reviewBusy,
                        decoration: const InputDecoration(
                          hintText: 'Share your experience…',
                        ),
                        minLines: 1,
                        maxLines: 3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _reviewBusy ? null : _submitReview,
                      child: const Text('Post'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_reviews.isEmpty)
                  const Text('No reviews yet — be the first')
                else
                  ..._reviews.take(8).map(
                    (r) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              r.userName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            '${r.rating}/5',
                            style: const TextStyle(
                              color: HubsomColors.gold,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        r.comment.trim().isEmpty
                            ? 'Rated this product'
                            : r.comment,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.mode_comment_outlined,
                    color: HubsomColors.forest,
                  ),
                  title: Text(
                    _comments.isEmpty
                        ? 'Comments'
                        : 'Comments (${_comments.length})',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text('Open the comment page'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _openComments,
                ),
                if (_suggested.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Suggested products',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 240,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _suggested.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, i) => SizedBox(
                        width: 160,
                        child: ProductCard(product: _suggested[i]),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: product.isAuctionLot
          ? null
          : ProductPurchaseBar(
        inStock: product.stock > 0,
        onAddToCart: () async {
          await ref.read(cartProvider.notifier).addProduct(
                product,
                source: 'buy-now',
              );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${product.name} added to cart'),
                action: SnackBarAction(
                  label: 'View cart',
                  onPressed: () => context.push('/cart'),
                ),
              ),
            );
          }
        },
        onBuyNow: () async {
          if (!ensureSignedIn(
            context,
            ref,
            message: 'Sign in to buy',
          )) {
            return;
          }
          await ref.read(cartProvider.notifier).addProduct(
                product,
                source: 'buy-now',
              );
          if (context.mounted) context.push('/checkout');
        },
      ),
    );
  }
}

enum _MediaKind { image, placeholder }

class _MediaSlide {
  const _MediaSlide._(this.kind, this.url);
  const _MediaSlide.image(String url) : this._(_MediaKind.image, url);
  const _MediaSlide.placeholder() : this._(_MediaKind.placeholder, null);

  final _MediaKind kind;
  final String? url;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HubsomColors.mint.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: HubsomColors.forest, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
