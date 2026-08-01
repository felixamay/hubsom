import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/categories.dart';
import '../../core/providers/core_providers.dart';
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
  final _picker = ImagePicker();
  final _images = <String>[];
  String _category = hubsomCategories.first.slug;
  bool _busy = false;
  String? _error;

  static const _minImages = 3;
  static const _maxImages = 8;

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
    setState(() => _error = null);
    try {
      final remaining = _maxImages - _images.length;
      if (remaining <= 0) {
        setState(() => _error = 'You can upload up to $_maxImages photos');
        return;
      }
      final picked = await _picker.pickMultiImage(
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 72,
        limit: remaining,
      );
      if (picked.isEmpty) return;

      for (final file in picked) {
        if (_images.length >= _maxImages) break;
        final bytes = await file.readAsBytes();
        // Keep uploads small enough for Hive / local store.
        if (bytes.lengthInBytes > 1_800_000) {
          setState(() => _error = 'Each photo must be under ~1.5MB after compress');
          continue;
        }
        final b64 = base64Encode(bytes);
        final mime = file.mimeType ?? 'image/jpeg';
        _images.add('data:$mime;base64,$b64');
      }
      if (mounted) setState(() {});
    } catch (e) {
      setState(() => _error = 'Could not pick images: $e');
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
              'At least $_minImages photos are required (up to $_maxImages).',
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
                          onPressed: () => setState(() => _images.removeAt(i)),
                          icon: const Icon(Icons.close, size: 16),
                        ),
                      ),
                    ],
                  ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pickImages,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(
                    _images.isEmpty
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
                  DropdownMenuItem(value: c.slug, child: Text(c.name)),
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
              onPressed: _busy ? null : _submit,
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
