import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/categories.dart';
import '../../core/providers/core_providers.dart';
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
    this.auctionLot = false,
  });
  final String? returnTo;
  /// When set, the form edits an existing listing.
  final String? productId;
  /// When set after create, attach the new product to this live show.
  final String? addToLiveStreamId;
  /// Create a live-auction lot that stays hidden from the public store.
  final bool auctionLot;

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
  String _category = hubsomCategories.first.slug;
  bool _busy = false;
  bool _picking = false;
  bool _loadingEdit = false;
  bool _flashEnabled = false;
  int _flashDiscountPct = 20;
  /// Hours until the flash sale ends (from save time).
  int _flashDurationHours = 24;
  DateTime? _existingFlashEndsAt;
  String? _error;
  late bool _auctionLot = widget.auctionLot;

  bool get _isEdit =>
      widget.productId != null && widget.productId!.trim().isNotEmpty;

  static const _minImages = 3;
  static const _maxImages = 8;
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isEdit) return;
    final kind = GoRouterState.of(context).uri.queryParameters['kind'];
    if (kind == 'auction') _auctionLot = true;
    if (kind == 'store') _auctionLot = false;
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
        final sale = product.flashSale;
        if (sale != null && sale.isActive) {
          _flashEnabled = true;
          _flashDiscountPct = sale.discountPct.clamp(5, 90);
          _existingFlashEndsAt = DateTime.tryParse(sale.endsAt);
          final end = _existingFlashEndsAt;
          if (end != null) {
            final hours =
                end.toUtc().difference(DateTime.now().toUtc()).inHours;
            if (hours <= 6) {
              _flashDurationHours = 6;
            } else if (hours <= 12) {
              _flashDurationHours = 12;
            } else if (hours <= 24) {
              _flashDurationHours = 24;
            } else if (hours <= 72) {
              _flashDurationHours = 72;
            } else {
              _flashDurationHours = 168;
            }
          }
        } else {
          _flashEnabled = false;
          _existingFlashEndsAt = null;
        }
        _auctionLot = product.auctionOnly;
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
      final body = <String, dynamic>{
        'name': _name.text.trim(),
        'description': _description.text.trim(),
        'category': _category,
        'priceGhs': double.tryParse(_price.text) ?? 0,
        'stock': int.tryParse(_stock.text) ?? 0,
        'images': List<String>.from(_images),
        'supports': _auctionLot
            ? ['live-auction']
            : ['buy-now', 'store-listing', 'live-selling'],
        'auctionOnly': _auctionLot,
      };
      if (_flashEnabled && !_auctionLot) {
        final endsAt = DateTime.now()
            .toUtc()
            .add(Duration(hours: _flashDurationHours))
            .toIso8601String();
        body['flashSale'] = {
          'endsAt': endsAt,
          'discountPct': _flashDiscountPct,
        };
      } else {
        body['flashSale'] = null;
      }
      final Map<String, dynamic> saved;
      if (_isEdit) {
        saved = await ref.read(sellerRepositoryProvider).updateProduct(
              widget.productId!.trim(),
              body,
            );
      } else {
        saved = await ref.read(sellerRepositoryProvider).createProduct(
              body,
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
          if (_auctionLot) {
            await ref.read(liveRepositoryProvider).startAuction(
                  streamId: liveId,
                  productId: id,
                );
          } else {
            await ref.read(liveRepositoryProvider).addProducts(
                  liveId,
                  [id],
                  quantities: {
                    id: int.tryParse(_stock.text.trim()) ?? 1,
                  },
                );
            await ref.read(liveRepositoryProvider).pinProduct(liveId, id);
          }
        } catch (_) {}
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _auctionLot
                  ? 'Auction lot is live — tap it anytime to start selling'
                  : 'Product added for sale on your live show',
            ),
          ),
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
        appBar: AppBar(
          title: Text(_isEdit
              ? (_auctionLot ? 'Edit auction lot' : 'Edit product')
              : (_auctionLot ? 'New auction lot' : 'New product')),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit
            ? (_auctionLot ? 'Edit auction lot' : 'Edit product')
            : (_auctionLot ? 'New auction lot' : 'New product')),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Store product'),
                  icon: Icon(Icons.storefront_outlined),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Auction lot'),
                  icon: Icon(Icons.gavel),
                ),
              ],
              selected: {_auctionLot},
              onSelectionChanged: _isEdit
                  ? null
                  : (next) => setState(() => _auctionLot = next.first),
            ),
            const SizedBox(height: 10),
            Text(
              _auctionLot
                  ? 'Hidden from your store. During live, tap this lot to start selling.'
                  : 'Shows in your store and marketplace. During live, tap it to sell at the listed price.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (widget.addToLiveStreamId != null &&
                widget.addToLiveStreamId!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: HubsomColors.mint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _auctionLot
                      ? 'Saving starts this auction on your live show. Tap the lot later to sell the next unit.'
                      : 'This product will join your live show at the listed price as soon as you save it.',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
            const SizedBox(height: 12),
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
              decoration: InputDecoration(
                labelText: _auctionLot
                    ? 'Asking / starting price (GHS)'
                    : 'Price (GHS)',
                helperText: _auctionLot
                    ? 'Used as the ask. Viewers bid up from a lower start on live.'
                    : null,
              ),
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
            if (!_auctionLot) ...[
            const SizedBox(height: 20),
            Text(
              'Flash sale',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: HubsomColors.forest,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Run a limited-time discount. It shows on the homepage Flash sales section while active.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'List as flash sale',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                _flashEnabled
                    ? 'Buyers see −$_flashDiscountPct% until the sale ends'
                    : 'Off — regular store price only',
              ),
              value: _flashEnabled,
              activeThumbColor: HubsomColors.live,
              onChanged: _busy
                  ? null
                  : (v) => setState(() => _flashEnabled = v),
            ),
            if (_flashEnabled) ...[
              const SizedBox(height: 4),
              Text(
                'Discount: $_flashDiscountPct%',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Slider(
                value: _flashDiscountPct.toDouble(),
                min: 5,
                max: 90,
                divisions: 17,
                label: '$_flashDiscountPct%',
                activeColor: HubsomColors.live,
                onChanged: _busy
                    ? null
                    : (v) => setState(() => _flashDiscountPct = v.round()),
              ),
              DropdownButtonFormField<int>(
                initialValue: _flashDurationHours,
                decoration: const InputDecoration(
                  labelText: 'Sale ends in',
                ),
                items: const [
                  DropdownMenuItem(value: 6, child: Text('6 hours')),
                  DropdownMenuItem(value: 12, child: Text('12 hours')),
                  DropdownMenuItem(value: 24, child: Text('24 hours')),
                  DropdownMenuItem(value: 72, child: Text('3 days')),
                  DropdownMenuItem(value: 168, child: Text('7 days')),
                ],
                onChanged: _busy
                    ? null
                    : (v) => setState(
                          () => _flashDurationHours = v ?? _flashDurationHours,
                        ),
              ),
              if (_existingFlashEndsAt != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Previous end: ${_existingFlashEndsAt!.toLocal()}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              Builder(
                builder: (context) {
                  final price = double.tryParse(_price.text.trim()) ?? 0;
                  if (price <= 0) return const SizedBox.shrink();
                  final sale = price * (1 - _flashDiscountPct / 100);
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Flash price ≈ GH₵ ${sale.toStringAsFixed(2)} (was GH₵ ${price.toStringAsFixed(2)})',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: HubsomColors.live,
                      ),
                    ),
                  );
                },
              ),
            ],
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy || _picking ? null : _submit,
              child: Text(
                _busy
                    ? (_isEdit ? 'Saving…' : 'Publishing…')
                    : (_isEdit
                        ? 'Save changes'
                        : (_auctionLot
                            ? 'Publish auction lot'
                            : 'Publish product')),
              ),
            ),
            if (kIsWeb)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Tip: use Add video on the Sell tab to post a shop clip linked to products.',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
