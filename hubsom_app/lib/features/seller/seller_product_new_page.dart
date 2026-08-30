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
import '../../widgets/hubsom_image.dart';

class SellerProductNewPage extends ConsumerStatefulWidget {
  const SellerProductNewPage({super.key, this.returnTo});
  final String? returnTo;

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
  String? _error;

  static const _minImages = 3;
  static const _maxImages = 8;
  /// After compression; raw camera files are resized first.
  static const _maxStoredBytes = 700_000;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _stock.dispose();
    super.dispose();
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
    return '/seller/go-live';
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
      await ref.read(sellerRepositoryProvider).createProduct({
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
      });
      ref.invalidate(productsProvider((category: null, q: null)));
      await ref.read(authStateProvider.notifier).refresh();
      if (!mounted) return;
      context.go(_returnTo);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New product')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
              decoration: const InputDecoration(labelText: 'Price (GHS)'),
              keyboardType: TextInputType.number,
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null || n <= 0) return 'Enter a valid price';
                return null;
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _stock,
              decoration: const InputDecoration(labelText: 'Stock'),
              keyboardType: TextInputType.number,
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n < 0) return 'Enter stock';
                return null;
              },
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
              onPressed: _busy || _picking ? null : _submit,
              child: Text(_busy ? 'Publishing…' : 'Publish product'),
            ),
            if (kIsWeb)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Tip: after publishing you return to Go live to start your show.',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
