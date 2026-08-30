import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/categories.dart';
import '../../core/providers/core_providers.dart';
import '../../core/services/product_demo_video_picker.dart';
import '../../core/services/product_photo_compress.dart';
import '../../core/services/product_photo_picker.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../models/product.dart';
import '../../widgets/hubsom_image.dart';

class SellerProductNewPage extends ConsumerStatefulWidget {
  const SellerProductNewPage({
    super.key,
    this.returnTo,
    this.productId,
    this.addToLiveStreamId,
  });
  final String? returnTo;
  /// When set, the form edits an existing listing.
  final String? productId;
  /// When set after create, attach the new product to this live show.
  final String? addToLiveStreamId;

  @override
  ConsumerState<SellerProductNewPage> createState() =>
      _SellerProductNewPageState();
}

class _SellerProductNewPageState extends ConsumerState<SellerProductNewPage> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _stock = TextEditingController(text: '10');
  final _formKey = GlobalKey<FormState>();
  final _images = <String>[];
  ProductDemoVideo? _demoVideo;
  String _category = hubsomCategories.first.slug;
  bool _busy = false;
  bool _picking = false;
  bool _pickingVideo = false;
  bool _loadingEdit = false;
  bool _existingHasVideo = false;
  bool _clearedVideo = false;
  String? _error;

  bool get _isEdit =>
      widget.productId != null && widget.productId!.trim().isNotEmpty;

  static const _minImages = 3;
  static const _maxImages = 8;
  static const _maxVideoSeconds = 15;
  static const _maxStoredBytes = 700_000;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _loadingEdit = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadExisting());
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _stock.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final id = widget.productId!.trim();
    try {
      final mine = await ref.read(sellerRepositoryProvider).myProducts();
      Product? product;
      for (final p in mine) {
        if (p.id == id) {
          product = p;
          break;
        }
      }
      product ??= await ref.read(catalogRepositoryProvider).getProduct(id);
      if (!mounted) return;
      if (product == null) {
        setState(() {
          _loadingEdit = false;
          _error = 'Product not found';
        });
        return;
      }
      _name.text = product.name;
      _description.text = product.description;
      _price.text = product.priceGhs.toStringAsFixed(
        product.priceGhs == product.priceGhs.roundToDouble() ? 0 : 2,
      );
      _stock.text = '${product.stock}';
      setState(() {
        _images
          ..clear()
          ..addAll(product!.images);
        _category = product.category;
        _existingHasVideo = product.hasDemoVideo || product.showsDemoVideo;
        _clearedVideo = false;
        _demoVideo = null;
        _loadingEdit = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingEdit = false;
        _error = '$e';
      });
    }
  }

  String get _returnTo {
    final fromWidget = widget.returnTo;
    if (fromWidget != null &&
        fromWidget.startsWith('/') &&
        !fromWidget.startsWith('//')) {
      return fromWidget;
    }
    final q = GoRouterState.of(context).uri.queryParameters['returnTo'];
    if (q != null && q.startsWith('/') && !q.startsWith('//')) return q;
    return '/seller';
  }

  Future<void> _pickImages() async {
    if (_picking) return;
    setState(() {
      _error = null;
      _picking = true;
    });
    try {
      final remaining = _maxImages - _images.length;
      if (remaining <= 0) {
        setState(() => _error = 'You can upload up to $_maxImages photos');
        return;
      }
      final picked = await pickProductPhotos(remaining: remaining);
      if (picked.isEmpty) return;

      var skipped = 0;
      for (final file in picked) {
        if (_images.length >= _maxImages) break;
        try {
          final compressed = await compressProductPhoto(file.bytes);
          if (compressed.isEmpty) {
            skipped++;
            continue;
          }
          if (compressed.lengthInBytes > _maxStoredBytes) {
            skipped++;
            continue;
          }
          _images.add(
            'data:image/jpeg;base64,${base64Encode(compressed)}',
          );
        } catch (_) {
          skipped++;
        }
      }
      if (!mounted) return;
      setState(() {
        if (_images.length < _minImages && skipped > 0) {
          _error =
              'Could not use $skipped photo${skipped == 1 ? '' : 's'}. Try clearer JPG/PNG shots — Hubsom compresses them automatically.';
        }
      });
    } catch (e) {
      setState(() => _error = 'Could not pick images. Try again or use JPG/PNG.');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _pickVideo() async {
    if (_pickingVideo) return;
    setState(() {
      _error = null;
      _pickingVideo = true;
    });
    try {
      final video = await pickProductDemoVideo(maxSeconds: _maxVideoSeconds);
      if (!mounted) return;
      setState(() => _demoVideo = video);
    } catch (e) {
      final message = '$e'
          .replaceFirst('Bad state: ', '')
          .replaceFirst('Exception: ', '');
      setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _pickingVideo = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_images.length < _minImages) {
      setState(
        () => _error =
            'Upload at least $_minImages product photos before publishing',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final body = {
        'name': _name.text.trim(),
        'description': _description.text.trim(),
        'category': _category,
        'priceGhs': double.tryParse(_price.text) ?? 0,
        'stock': int.tryParse(_stock.text) ?? 0,
        'images': List<String>.from(_images),
        'supports': [
          'buy-now',
          'store-listing',
          'live-selling',
          'live-auction',
        ],
      };
      final Map<String, dynamic> saved;
      if (_isEdit) {
        saved = await ref.read(sellerRepositoryProvider).updateProduct(
              widget.productId!.trim(),
              body,
              demoVideoBytes: _demoVideo?.bytes,
              demoVideoMimeType: _demoVideo?.mimeType,
              clearDemoVideo: _clearedVideo && _demoVideo == null,
            );
      } else {
        saved = await ref.read(sellerRepositoryProvider).createProduct(
              body,
              demoVideoBytes: _demoVideo?.bytes,
              demoVideoMimeType: _demoVideo?.mimeType,
            );
      }
      ref.invalidate(productsProvider((category: null, q: null)));
      await ref.read(authStateProvider.notifier).refresh();
      if (!mounted) return;
      final id = '${saved['id'] ?? widget.productId ?? ''}';
      final liveId = widget.addToLiveStreamId?.trim();
      if (!_isEdit &&
          liveId != null &&
          liveId.isNotEmpty &&
          id.isNotEmpty) {
        try {
          await ref.read(liveRepositoryProvider).addProducts(liveId, [id]);
          await ref.read(liveRepositoryProvider).pinProduct(liveId, id);
        } catch (_) {}
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product added to your live show')),
        );
        context.go('/live/$liveId?host=1');
        return;
      }
      if (_isEdit) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product updated')),
        );
        context.go(id.isNotEmpty ? '/products/$id' : _returnTo);
      } else if (_returnTo == '/seller' && id.isNotEmpty) {
        context.go('/products/$id');
      } else {
        context.go(_returnTo);
      }
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingEdit) {
      return Scaffold(
        appBar: AppBar(title: Text(_isEdit ? 'Edit product' : 'New product')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit product' : 'New product')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.addToLiveStreamId != null &&
                widget.addToLiveStreamId!.trim().isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: HubsomColors.mint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'This product will be published and pinned on your live show as soon as you save it.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              'Product photos',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: HubsomColors.forest,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'At least $_minImages photos are required (up to $_maxImages). Phone camera shots are compressed automatically.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _images.length; i++)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: HubsomImage(
                          url: _images[i],
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: IconButton(
                          visualDensity: VisualDensity.compact,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black54,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _busy || _picking
                              ? null
                              : () => setState(() => _images.removeAt(i)),
                          icon: const Icon(Icons.close, size: 16),
                        ),
                      ),
                    ],
                  ),
                OutlinedButton.icon(
                  onPressed: _busy || _picking ? null : _pickImages,
                  icon: _picking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_a_photo_outlined),
                  label: Text(
                    _picking
                        ? 'Compressing…'
                        : _images.isEmpty
                            ? 'Add photos'
                            : '${_images.length}/$_maxImages',
                  ),
                ),
              ],
            ),
            if (_images.length < _minImages)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${_minImages - _images.length} more photo${_minImages - _images.length == 1 ? '' : 's'} required',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Text(
              'Product demo video',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: HubsomColors.forest,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Optional. Prefer not to go live? Add a short clip (up to $_maxVideoSeconds seconds) to show the product.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            if (_demoVideo != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.videocam, color: HubsomColors.forest),
                title: Text(_demoVideo!.name),
                subtitle: Text(
                  '${_demoVideo!.durationSeconds.toStringAsFixed(1)}s · ${(_demoVideo!.bytes.lengthInBytes / 1024).round()} KB',
                ),
                trailing: IconButton(
                  tooltip: 'Remove video',
                  onPressed: _busy || _pickingVideo
                      ? null
                      : () => setState(() {
                            _demoVideo = null;
                            _clearedVideo = true;
                          }),
                  icon: const Icon(Icons.close),
                ),
              )
            else if (_existingHasVideo && !_clearedVideo)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.videocam, color: HubsomColors.forest),
                title: const Text('Current demo video'),
                subtitle: const Text('Kept on this listing'),
                trailing: IconButton(
                  tooltip: 'Remove video',
                  onPressed: _busy || _pickingVideo
                      ? null
                      : () => setState(() {
                            _clearedVideo = true;
                            _demoVideo = null;
                          }),
                  icon: const Icon(Icons.close),
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: _busy || _pickingVideo
                    ? null
                    : () async {
                        await _pickVideo();
                        if (_demoVideo != null) {
                          setState(() => _clearedVideo = false);
                        }
                      },
                icon: _pickingVideo
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.video_call_outlined),
                label: Text(
                  _pickingVideo
                      ? 'Checking video…'
                      : 'Add demo video (max ${_maxVideoSeconds}s)',
                ),
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name required' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 4,
              validator: (v) => (v == null || v.trim().length < 10)
                  ? 'Add a short description'
                  : null,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _category,
              items: [
                for (final c in hubsomCategories)
                  DropdownMenuItem(
                    value: c.slug,
                    child: Row(
                      children: [
                        Icon(c.icon, size: 20),
                        const SizedBox(width: 8),
                        Flexible(child: Text(c.name)),
                      ],
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _category = v ?? _category),
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _price,
              decoration: const InputDecoration(labelText: 'Price (GHS)'),
              keyboardType: TextInputType.number,
              validator: (v) =>
                  ((double.tryParse(v ?? '') ?? 0) <= 0) ? 'Enter a valid price' : null,
            ),
            const SizedBox(height: 12),
            Text(
              'How many are you selling?',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: HubsomColors.forest,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Set the quantity available for this listing. Buyers see how many are left.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: _busy
                      ? null
                      : () {
                          final n = int.tryParse(_stock.text.trim()) ?? 0;
                          if (n <= 1) return;
                          setState(() => _stock.text = '${n - 1}');
                        },
                  icon: const Icon(Icons.remove),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _stock,
                    decoration: const InputDecoration(
                      labelText: 'Quantity for sale',
                      hintText: 'e.g. 25',
                    ),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n < 1) {
                        return 'Enter how many you are selling (at least 1)';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _busy
                      ? null
                      : () {
                          final n = int.tryParse(_stock.text.trim()) ?? 0;
                          setState(() => _stock.text = '${n + 1}');
                        },
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy || _picking || _pickingVideo ? null : _submit,
              child: Text(
                _busy
                    ? (_isEdit ? 'Saving…' : 'Publishing…')
                    : (_isEdit ? 'Save changes' : 'Publish product'),
              ),
            ),
            if (kIsWeb)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Tip: add a demo video if you are not going live, or go live later from Sell.',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
