import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/core_providers.dart';
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
  final _selected = <String>{};
  String? _auctionProductId;
  bool _auction = false;
  /// Auction clock set by seller — max 30 seconds.
  int _auctionSeconds = 30;
  bool _busy = false;
  String? _error;
  List<Product> _products = const [];
  bool _loadingProducts = true;

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
          _selected
            ..clear()
            ..add(_products.first.id);
          _auctionProductId = _products.first.id;
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
    super.dispose();
  }

  Future<void> _start() async {
    if (_selected.isEmpty) {
      setState(() => _error = 'Select at least one of your products for the show');
      return;
    }
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Add a stream title');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final stream = await ref.read(liveRepositoryProvider).createStream({
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'status': 'live',
        'productIds': _selected.toList(),
        'pinnedProductId': _selected.first,
        if (_auction) 'auctionProductId': _auctionProductId ?? _selected.first,
        if (_auction)
          'startingBidGhs': double.tryParse(_startingBid.text.trim()) ?? 50,
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
      if (mounted) setState(() => _error = '$e');
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
                  'Pick products, optionally open an auction, then go live. Viewers can chat, react, bid, and buy.',
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
                            'You need at least one product before going live. Create a product with 3+ photos, then you will return here.',
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () => context.push(
                              '/seller/products/new?returnTo=${Uri.encodeComponent('/seller/go-live')}',
                            ),
                            child: const Text('Create a product'),
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
                    return CheckboxListTile(
                      value: selected,
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
                        '${formatGhs(p.effectivePrice)} · ${p.images.length} photos',
                      ),
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selected.add(p.id);
                          } else {
                            _selected.remove(p.id);
                            if (_auctionProductId == p.id) {
                              _auctionProductId =
                                  _selected.isNotEmpty ? _selected.first : null;
                            }
                          }
                        });
                      },
                    );
                  }),
                if (_products.isNotEmpty) ...[
                  TextButton(
                    onPressed: () => context.push(
                      '/seller/products/new?returnTo=${Uri.encodeComponent('/seller/go-live')}',
                    ),
                    child: const Text('Add another product'),
                  ),
                ],
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Include live auction'),
                  subtitle: const Text('Viewers can bid on one product'),
                  value: _auction,
                  onChanged: _products.isEmpty || _selected.isEmpty
                      ? null
                      : (v) => setState(() {
                            _auction = v;
                            _auctionProductId ??= _selected.first;
                          }),
                ),
                if (_auction && _selected.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    key: ValueKey(
                      'auction-${_selected.join(',')}-${_auctionProductId ?? ''}',
                    ),
                    initialValue: _selected.contains(_auctionProductId ?? '')
                        ? _auctionProductId
                        : _selected.first,
                    items: [
                      for (final id in _selected)
                        DropdownMenuItem(
                          value: id,
                          child: Text(
                            _products.firstWhere((p) => p.id == id).name,
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _auctionProductId = v),
                    decoration:
                        const InputDecoration(labelText: 'Auction product'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _startingBid,
                    decoration: const InputDecoration(
                      labelText: 'Starting bid (GHS)',
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
                    'Countdown starts when you go live. Late bids can add a few seconds.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: HubsomColors.ink.withValues(alpha: 0.65),
                        ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _busy || _products.isEmpty ? null : _start,
                  icon: const Icon(Icons.videocam),
                  label: Text(_busy ? 'Starting…' : 'Start live stream'),
                ),
              ],
            ),
    );
  }
}
