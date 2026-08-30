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
  List<ProductComment> _comments = const [];
  bool _loading = true;
  String? _error;
  bool _saved = false;
  bool _liked = false;
  int _likes = 0;
  bool _busy = false;
  final _commentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
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
      if (!mounted) return;
      setState(() {
        _product = product;
        _comments = comments;
        _saved = catalog.isSaved(product.id);
        _liked = catalog.isLiked(product.id);
        _likes = catalog.likeCount(product.id);
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

    return Scaffold(
      appBar: AppBar(
        title: Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: _saved ? 'Saved' : 'Save',
            icon: Icon(_saved ? Icons.bookmark : Icons.bookmark_border),
            onPressed: _toggleSave,
          ),
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.ios_share),
            onPressed: _shareSheet,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AspectRatio(
            aspectRatio: 1.1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: HubsomImage(
                url: image,
                fit: BoxFit.cover,
                placeholder: Container(
                  color: HubsomColors.mist,
                  child: const Icon(Icons.image, size: 64),
                ),
              ),
            ),
          ),
          if (product.images.length > 1) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: product.images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: HubsomImage(
                    url: product.images[i],
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ],
          if (product.showsDemoVideo) ...[
            const SizedBox(height: 16),
            Text(
              'Product demo',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            ProductDemoVideoPlayer(
              productId: product.id,
              remoteUrl: product.demoVideoUrl,
            ),
          ],
          const SizedBox(height: 16),
          Text(
            product.name,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            formatGhs(product.effectivePrice),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: HubsomColors.forest,
                  fontWeight: FontWeight.w800,
                ),
          ),
          if (product.compareAtGhs != null)
            Text(
              formatGhs(product.compareAtGhs!),
              style: const TextStyle(
                decoration: TextDecoration.lineThrough,
                color: Colors.grey,
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton.icon(
                onPressed: _toggleLike,
                icon: Icon(
                  _liked ? Icons.favorite : Icons.favorite_border,
                  color: _liked ? HubsomColors.live : null,
                ),
                label: Text('$_likes'),
              ),
              TextButton.icon(
                onPressed: () => FocusScope.of(context).requestFocus(FocusNode()),
                icon: const Icon(Icons.mode_comment_outlined),
                label: Text('${_comments.length}'),
              ),
              TextButton.icon(
                onPressed: _shareSheet,
                icon: const Icon(Icons.ios_share),
                label: const Text('Share'),
              ),
              const Spacer(),
              Text('Stock: ${product.stock}'),
            ],
          ),
          const SizedBox(height: 8),
          Text(product.description),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              for (final t in product.tags)
                Chip(label: Text(t), visualDensity: VisualDensity.compact),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Comments',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
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
                    if (!ensureSignedIn(context, ref, message: 'Sign in to buy')) {
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
