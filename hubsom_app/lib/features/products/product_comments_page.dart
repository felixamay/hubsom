import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/require_auth.dart';
import '../../core/providers/core_providers.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../models/product.dart';
import '../../models/product_social.dart';
import '../../widgets/hubsom_image.dart';

/// Dedicated comments screen for a product (opened from the Comment action).
class ProductCommentsPage extends ConsumerStatefulWidget {
  const ProductCommentsPage({super.key, required this.productId});
  final String productId;

  @override
  ConsumerState<ProductCommentsPage> createState() =>
      _ProductCommentsPageState();
}

class _ProductCommentsPageState extends ConsumerState<ProductCommentsPage> {
  Product? _product;
  List<ProductComment> _comments = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  final _commentCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _scrollCtrl.dispose();
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
      final comments = product == null
          ? const <ProductComment>[]
          : await catalog.listComments(product.id);
      if (!mounted) return;
      setState(() {
        _product = product;
        _comments = comments;
        _loading = false;
        if (product == null) _error = 'Product not found';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _submit() async {
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
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _when(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Comments')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _product == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Comments')),
        body: Center(child: Text(_error ?? 'Product not found')),
      );
    }
    final product = _product!;
    final thumb = product.images.isNotEmpty ? product.images.first : '';
    final initial = product.name.isNotEmpty
        ? product.name.substring(0, 1).toUpperCase()
        : 'P';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comments'),
        actions: [
          TextButton(
            onPressed: () => context.push('/products/${product.id}'),
            child: const Text('Product'),
          ),
        ],
      ),
      body: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.45),
            child: InkWell(
              onTap: () => context.push('/products/${product.id}'),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: thumb.isEmpty
                          ? Container(
                              width: 52,
                              height: 52,
                              color: HubsomColors.mint,
                              alignment: Alignment.center,
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: HubsomColors.forest,
                                ),
                              ),
                            )
                          : HubsomImage(
                              url: thumb,
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                            ),
                    ),
                    const SizedBox(width: 12),
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
                            '${_comments.length} comment${_comments.length == 1 ? '' : 's'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _comments.isEmpty
                ? const Center(
                    child: Text('No comments yet — be the first'),
                  )
                : ListView.separated(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: _comments.length,
                    separatorBuilder: (_, __) => const Divider(height: 20),
                    itemBuilder: (_, i) {
                      final c = _comments[i];
                      final letter = c.userName.isNotEmpty
                          ? c.userName.substring(0, 1).toUpperCase()
                          : '?';
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: HubsomColors.mint,
                            child: Text(
                              letter,
                              style: const TextStyle(
                                color: HubsomColors.forest,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        c.userName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      _when(c.createdAt),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: Colors.grey),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(c.text),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentCtrl,
                      enabled: !_busy,
                      decoration: const InputDecoration(
                        hintText: 'Add a comment…',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _busy ? null : _submit,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
