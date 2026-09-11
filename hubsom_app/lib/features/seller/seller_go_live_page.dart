import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/core_providers.dart';
import '../../core/services/product_photo_compress.dart';
import '../../core/services/product_photo_picker.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../core/utils/money.dart';
import '../../models/product.dart';
import '../../widgets/hubsom_image.dart';

class SellerGoLivePage extends ConsumerStatefulWidget {
  const SellerGoLivePage({super.key});
  @override
  ConsumerState<SellerGoLivePage> createState() => _SellerGoLivePageState();
}

class _SellerGoLivePageState extends ConsumerState<SellerGoLivePage> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _startingBid = TextEditingController(text: '50');
  final _askingPrice = TextEditingController();
  final _selected = <String>{};
  final _qtys = <String, int>{};
  String? _auctionProductId;
  bool _auction = false;
  /// Auction clock set by seller — max 30 seconds.
  int _auctionSeconds = 30;
  bool _busy = false;
  bool _pickingCover = false;
  String? _coverDataUrl;
  String? _error;
  List<Product> _products = const [];
  bool _loadingProducts = true;

  static const _maxStoredBytes = 700_000;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProducts());
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loadingProducts = true;
      _error = null;
    });
    try {
      final products = await ref.read(sellerRepositoryProvider).myProducts();
      if (!mounted) return;
      setState(() {
        _products = products;
        _loadingProducts = false;
        if (_products.isNotEmpty) {
          final firstStore = _storeProducts.isNotEmpty
              ? _storeProducts.first
              : _products.first;
          _selected
            ..clear()
            ..add(firstStore.id);
          _qtys[firstStore.id] = _defaultQty(firstStore);
          if (_auctionLots.isNotEmpty) {
            _auctionProductId = _auctionLots.first.id;
            _askingPrice.text =
                _auctionLots.first.effectivePrice.toStringAsFixed(0);
          }
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingProducts = false;
          _error = 'Could not load products: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _startingBid.dispose();
    _askingPrice.dispose();
    super.dispose();
  }

  List<Product> get _storeProducts =>
      _products.where((p) => !p.isAuctionLot).toList();

  List<Product> get _auctionLots =>
      _products.where((p) => p.isAuctionLot).toList();

  int _defaultQty(Product p) => p.stock < 1 ? 0 : 1;

  int _qtyFor(Product p) {
    final q = _qtys[p.id] ?? _defaultQty(p);
    if (p.stock < 1) return 0;
    return q.clamp(1, p.stock);
  }

  void _setQty(Product p, int qty) {
    if (p.stock < 1) return;
    setState(() => _qtys[p.id] = qty.clamp(1, p.stock));
  }

  Future<void> _pickCover() async {
    if (_pickingCover || _busy) return;
    setState(() {
      _pickingCover = true;
      _error = null;
    });
    try {
      final picked = await pickProductPhotos(remaining: 1);
      if (picked.isEmpty) return;
      final compressed = await compressProductPhoto(
        picked.first.bytes,
        maxSide: 960,
        quality: 80,
      );
      if (compressed.isEmpty) {
        setState(() => _error = 'Could not use that photo. Try another JPG/PNG.');
        return;
      }
      if (compressed.lengthInBytes > _maxStoredBytes) {
        setState(
          () => _error =
              'Photo is still too large after compress. Try a clearer, smaller shot.',
        );
        return;
      }
      setState(() {
        _coverDataUrl = 'data:image/jpeg;base64,${base64Encode(compressed)}';
      });
    } catch (_) {
      setState(() => _error = 'Could not pick a thumbnail. Try again.');
    } finally {
      if (mounted) setState(() => _pickingCover = false);
    }
  }

  Future<void> _start() async {
    if (_coverDataUrl == null || _coverDataUrl!.trim().isEmpty) {
      setState(() => _error = 'Add a thumbnail for Watch live and Live now');
      return;
    }
    if (_selected.isEmpty) {
      setState(() => _error = 'Select at least one of your products for the show');
      return;
    }
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Add a stream title');
      return;
    }
    for (final id in _selected) {
      final matches = _products.where((p) => p.id == id);
      if (matches.isEmpty) continue;
      final product = matches.first;
      final qty = _qtyFor(product);
      if (qty < 1) {
        setState(
          () => _error =
              'Set a quantity for ${product.name} before going live',
        );
        return;
      }
      if (qty > product.stock) {
        setState(
          () => _error =
              '${product.name} only has ${product.stock} in stock',
        );
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final stream = await ref.read(liveRepositoryProvider).createStream({
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'cover': _coverDataUrl,
        'status': 'live',
        'productIds': _selected.toList(),
        'productQuantities': {
          for (final id in _selected)
            id: _qtys[id] ??
                _defaultQty(_products.firstWhere((p) => p.id == id)),
        },
        'pinnedProductId': _selected.first,
        if (_auction) 'auctionProductId': _auctionProductId ?? _selected.first,
        if (_auction)
          'startingBidGhs': double.tryParse(_startingBid.text.trim()) ?? 50,
        if (_auction)
          'askingPriceGhs': double.tryParse(_askingPrice.text.trim()),
        if (_auction) 'auctionDurationSeconds': _auctionSeconds.clamp(1, 30),
      });

      ref.invalidate(streamsProvider);
      await ref.read(authStateProvider.notifier).refresh();
      if (!mounted) return;

      // Navigate immediately — Agora join happens inside the room (web-safe stub).
      final dest = Uri(
        path: '/live/${stream.id}',
        queryParameters: const {'host': '1'},
      ).toString();
      context.go(dest);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e'
              .replaceFirst('Bad state: ', '')
              .replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Go live'),
        actions: [
          IconButton(
            tooltip: 'Refresh products',
            onPressed: _loadingProducts ? null : _loadProducts,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      bottomNavigationBar: _loadingProducts
          ? null
          : Material(
              elevation: 8,
              color: Theme.of(context).scaffoldBackgroundColor,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ...[
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      FilledButton.icon(
                        onPressed: _busy || _products.isEmpty ? null : _start,
                        icon: const Icon(Icons.videocam),
                        label: Text(_busy ? 'Starting…' : 'Start live stream'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      body: _loadingProducts
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Start a Hubsom live show',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: HubsomColors.forest,
                      ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Store products sell at the listed price. Auction lots are created separately and stay hidden from your store — tap one on live to start selling.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Stream title'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _description,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Text(
                  'Show thumbnail',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Required — this photo is what shoppers see on Watch live and Live now.',
                ),
                const SizedBox(height: 10),
                Material(
                  key: const Key('live-thumbnail-picker'),
                  color: HubsomColors.mint.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: _busy || _pickingCover ? null : _pickCover,
                    borderRadius: BorderRadius.circular(14),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: _coverDataUrl == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_pickingCover)
                                  const CircularProgressIndicator()
                                else
                                  Icon(
                                    Icons.add_photo_alternate_outlined,
                                    size: 40,
                                    color: HubsomColors.forest.withValues(
                                      alpha: 0.7,
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                Text(
                                  _pickingCover
                                      ? 'Compressing…'
                                      : 'Choose thumbnail',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            )
                          : Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: HubsomImage(
                                    url: _coverDataUrl,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  right: 8,
                                  bottom: 8,
                                  child: FilledButton.tonalIcon(
                                    onPressed:
                                        _busy || _pickingCover ? null : _pickCover,
                                    icon: const Icon(Icons.photo_camera_outlined),
                                    label: Text(
                                      _pickingCover ? 'Compressing…' : 'Change',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Products in this show',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                if (_products.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Create a store product or a hidden auction lot (3+ photos), then come back here.',
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () => context.push(
                              '/seller/products/new?returnTo=${Uri.encodeComponent('/seller/go-live')}&kind=store',
                            ),
                            child: const Text('Create store product'),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: () => context.push(
                              '/seller/products/new?returnTo=${Uri.encodeComponent('/seller/go-live')}&kind=auction',
                            ),
                            child: const Text('Create auction lot'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ..._products.map((p) {
                    final selected = _selected.contains(p.id);
                    final thumb =
                        p.images.isNotEmpty ? p.images.first : null;
                    final out = p.stock < 1;
                    final qty = _qtyFor(p);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(4, 4, 8, 8),
                        child: Column(
                          children: [
                            CheckboxListTile(
                              value: selected,
                              enabled: !out,
                              contentPadding: EdgeInsets.zero,
                              secondary: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: HubsomImage(
                                  url: thumb,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              title: Text(p.name),
                              subtitle: Text(
                                out
                                    ? 'Out of stock — add quantity on the product first'
                                    : p.isAuctionLot
                                        ? '${formatGhs(p.effectivePrice)} · ${p.stock} auction lot · hidden from store'
                                        : '${formatGhs(p.effectivePrice)} · ${p.stock} in store',
                              ),
                              onChanged: out
                                  ? null
                                  : (v) {
                                      setState(() {
                                        if (v == true) {
                                          _selected.add(p.id);
                                          _qtys[p.id] = _defaultQty(p);
                                        } else {
                                          _selected.remove(p.id);
                                          if (_auctionProductId == p.id) {
                                            _auctionProductId =
                                                _selected.isNotEmpty
                                                    ? _selected.first
                                                    : null;
                                          }
                                        }
                                      });
                                    },
                            ),
                            if (selected && !out)
                              Padding(
                                padding: const EdgeInsets.only(left: 8, right: 4),
                                child: Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'Quantity for this live',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Fewer',
                                      onPressed: qty <= 1
                                          ? null
                                          : () => _setQty(p, qty - 1),
                                      icon: const Icon(Icons.remove_circle_outline),
                                    ),
                                    Text(
                                      '$qty',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'More',
                                      onPressed: qty >= p.stock
                                          ? null
                                          : () => _setQty(p, qty + 1),
                                      icon: const Icon(Icons.add_circle_outline),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                if (_products.isNotEmpty) ...[
                  TextButton(
                    onPressed: () => context.push(
                      '/seller/products/new?returnTo=${Uri.encodeComponent('/seller/go-live')}&kind=store',
                    ),
                    child: const Text('Add store product'),
                  ),
                  TextButton(
                    onPressed: () => context.push(
                      '/seller/products/new?returnTo=${Uri.encodeComponent('/seller/go-live')}&kind=auction',
                    ),
                    child: const Text('Add auction lot'),
                  ),
                ],
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Start with an auction lot'),
                  subtitle: Text(
                    _auctionLots.isEmpty
                        ? 'Create an auction lot first — it stays hidden from your store'
                        : 'Tap that lot on live to keep selling. Hidden from store.',
                  ),
                  value: _auction,
                  onChanged: _auctionLots.isEmpty
                      ? null
                      : (v) => setState(() {
                            _auction = v;
                            _auctionProductId ??= _auctionLots.first.id;
                            if (v && _auctionProductId != null) {
                              _selected.add(_auctionProductId!);
                              final lot = _auctionLots.firstWhere(
                                (p) => p.id == _auctionProductId,
                              );
                              _qtys[_auctionProductId!] = _defaultQty(lot);
                            }
                          }),
                ),
                if (_auction && _auctionLots.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    key: ValueKey(
                      'auction-${_auctionLots.map((p) => p.id).join(',')}-${_auctionProductId ?? ''}',
                    ),
                    initialValue: _auctionLots.any((p) => p.id == _auctionProductId)
                        ? _auctionProductId
                        : _auctionLots.first.id,
                    items: [
                      for (final p in _auctionLots)
                        DropdownMenuItem(
                          value: p.id,
                          child: Text(p.name),
                        ),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _auctionProductId = v;
                        if (v == null) return;
                        _selected.add(v);
                        for (final p in _auctionLots) {
                          if (p.id == v) {
                            _qtys[v] = _defaultQty(p);
                            _askingPrice.text =
                                p.effectivePrice.toStringAsFixed(0);
                            break;
                          }
                        }
                      });
                    },
                    decoration:
                        const InputDecoration(labelText: 'Auction lot'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _startingBid,
                    decoration: const InputDecoration(
                      labelText: 'Starting bid (GHS)',
                      helperText: 'Opening price viewers can bid from',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _askingPrice,
                    decoration: const InputDecoration(
                      labelText: 'Asking / sale price (GHS)',
                      helperText:
                          'Only you see this. Auction won’t sell below it — you can extend live if unmet.',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Auction time · $_auctionSeconds s (max 30)',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  Slider(
                    value: _auctionSeconds.toDouble(),
                    min: 5,
                    max: 30,
                    divisions: 25,
                    label: '$_auctionSeconds s',
                    onChanged: (v) =>
                        setState(() => _auctionSeconds = v.round()),
                  ),
                  Text(
                    'Countdown starts when you go live. You can extend if asking price isn’t met.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: HubsomColors.ink.withValues(alpha: 0.65),
                        ),
                  ),
                ],
                const SizedBox(height: 12),
              ],
            ),
    );
  }
}
