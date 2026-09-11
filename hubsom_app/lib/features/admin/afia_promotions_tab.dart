import 'package:flutter/material.dart';

import '../../core/constants/categories.dart';
import '../../core/services/local_commerce_store.dart';
import '../../core/services/local_promotion_store.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../models/promotion.dart';

/// HubsomAdmin promotions editor, hosted inside the Afia portal.
class AfiaPromotionsTab extends StatefulWidget {
  const AfiaPromotionsTab({super.key});

  @override
  State<AfiaPromotionsTab> createState() => _AfiaPromotionsTabState();
}

class _AfiaPromotionsTabState extends State<AfiaPromotionsTab> {
  final _title = TextEditingController();
  final _subtitle = TextEditingController();
  final _href = TextEditingController(text: '/marketplace');
  final _cta = TextEditingController(text: 'Shop now');
  final _imageUrl = TextEditingController();
  final _placements = <String>{'landing'};
  final _categories = <String>{};
  final _products = <String>{};
  String? _editingId;
  bool _active = true;
  bool _busy = false;
  String? _error;
  String? _status;
  List<Promotion> _items = const [];

  @override
  void initState() {
    super.initState();
    _items = LocalPromotionStore.all();
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _href.dispose();
    _cta.dispose();
    _imageUrl.dispose();
    super.dispose();
  }

  void _resetForm() {
    _editingId = null;
    _title.clear();
    _subtitle.clear();
    _href.text = '/marketplace';
    _cta.text = 'Shop now';
    _imageUrl.clear();
    _placements
      ..clear()
      ..add('landing');
    _categories.clear();
    _products.clear();
    _active = true;
  }

  void _edit(Promotion promo) {
    setState(() {
      _editingId = promo.id;
      _title.text = promo.title;
      _subtitle.text = promo.subtitle ?? '';
      _href.text = promo.href ?? '/marketplace';
      _cta.text = promo.ctaLabel ?? 'Shop now';
      _imageUrl.text = promo.imageUrl ?? '';
      _placements
        ..clear()
        ..addAll(promo.placementIds);
      _categories
        ..clear()
        ..addAll(promo.categorySlugs);
      _products
        ..clear()
        ..addAll(promo.productIds);
      _active = promo.active;
      _error = null;
      _status = null;
    });
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
      _status = null;
    });
    try {
      if (_editingId == null) {
        await LocalPromotionStore.create(
          title: _title.text,
          subtitle: _subtitle.text,
          href: _href.text,
          ctaLabel: _cta.text,
          imageUrl: _imageUrl.text.trim().isEmpty ? null : _imageUrl.text.trim(),
          placements: _placements.toList(),
          categorySlugs: _categories.toList(),
          productIds: _products.toList(),
          active: _active,
        );
      } else {
        await LocalPromotionStore.upsert(
          Promotion(
            id: _editingId!,
            title: _title.text,
            subtitle: _subtitle.text,
            href: _href.text,
            ctaLabel: _cta.text,
            imageUrl: _imageUrl.text.trim().isEmpty ? null : _imageUrl.text.trim(),
            placement: _placements.isNotEmpty ? _placements.first : 'landing',
            placements: _placements.toList(),
            categorySlugs: _categories.toList(),
            productIds: _products.toList(),
            active: _active,
          ),
        );
      }
      if (!mounted) return;
      _resetForm();
      setState(() {
        _items = LocalPromotionStore.all();
        _busy = false;
        _status = 'Saved to Hubsom';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e'.replaceFirst('Bad state: ', '');
      });
    }
  }

  Future<void> _delete(String id) async {
    await LocalPromotionStore.remove(id);
    if (!mounted) return;
    if (_editingId == id) _resetForm();
    setState(() => _items = LocalPromotionStore.all());
  }

  @override
  Widget build(BuildContext context) {
    final products = LocalCommerceStore.listProducts();
    final needsCategories = _placements.contains('category');
    final needsProducts = _placements.contains('product');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(
          'Hubsom promotions',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: HubsomColors.forest,
              ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Choose where each promo appears: landing, marketplace, category, and/or product. Empty category or product lists mean all pages.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _title,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _subtitle,
          decoration: const InputDecoration(labelText: 'Subtitle'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _href,
          decoration: const InputDecoration(
            labelText: 'Link',
            helperText: 'Hubsom path such as /marketplace or /categories/fashion',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _cta,
          decoration: const InputDecoration(labelText: 'Button label'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _imageUrl,
          decoration: const InputDecoration(labelText: 'Image URL (optional)'),
        ),
        const SizedBox(height: 16),
        Text(
          'Placements',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        for (final slot in LocalPromotionStore.placements)
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: _placements.contains(slot.id),
            title: Text(slot.label),
            subtitle: Text(slot.description),
            onChanged: (on) {
              setState(() {
                if (on == true) {
                  _placements.add(slot.id);
                } else {
                  _placements.remove(slot.id);
                }
              });
            },
          ),
        if (needsCategories) ...[
          const SizedBox(height: 8),
          Text(
            'Categories (empty = all)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          Wrap(
            spacing: 6,
            children: [
              for (final cat in hubsomCategories)
                FilterChip(
                  label: Text(cat.name),
                  selected: _categories.contains(cat.slug),
                  onSelected: (on) {
                    setState(() {
                      if (on) {
                        _categories.add(cat.slug);
                      } else {
                        _categories.remove(cat.slug);
                      }
                    });
                  },
                ),
            ],
          ),
        ],
        if (needsProducts) ...[
          const SizedBox(height: 8),
          Text(
            'Products (empty = all)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          if (products.isEmpty)
            const Text('No products on this device yet')
          else
            for (final product in products.take(40))
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _products.contains(product.id),
                title: Text(product.name),
                subtitle: Text(product.category),
                onChanged: (on) {
                  setState(() {
                    if (on == true) {
                      _products.add(product.id);
                    } else {
                      _products.remove(product.id);
                    }
                  });
                },
              ),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Active on Hubsom'),
          value: _active,
          onChanged: (v) => setState(() => _active = v),
        ),
        if (_error != null)
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (_status != null)
          Text(_status!, style: const TextStyle(color: HubsomColors.lime)),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(
            _busy
                ? 'Saving…'
                : _editingId == null
                    ? 'Save promotion to Hubsom'
                    : 'Update promotion',
          ),
        ),
        if (_editingId != null)
          TextButton(
            onPressed: () => setState(_resetForm),
            child: const Text('Cancel edit'),
          ),
        const SizedBox(height: 24),
        Text(
          'Live on Hubsom',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        if (_items.isEmpty)
          const Text('No promotions yet')
        else
          for (final item in _items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(item.title),
              subtitle: Text(
                [
                  item.placementIds.join(', '),
                  if (!item.active) 'off',
                ].join(' · '),
              ),
              trailing: Wrap(
                children: [
                  TextButton(
                    onPressed: () => _edit(item),
                    child: const Text('Edit'),
                  ),
                  TextButton(
                    onPressed: () => _delete(item.id),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
