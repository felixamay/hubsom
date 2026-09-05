import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/categories.dart';
import '../../core/services/local_purchase_offer_store.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../models/purchase_offer.dart';

class AdminOffersPage extends ConsumerStatefulWidget {
  const AdminOffersPage({super.key});

  @override
  ConsumerState<AdminOffersPage> createState() => _AdminOffersPageState();
}

class _AdminOffersPageState extends ConsumerState<AdminOffersPage> {
  final _title = TextEditingController();
  final _subtitle = TextEditingController();
  final _href = TextEditingController(text: '/marketplace');
  final _cta = TextEditingController(text: 'Shop now');
  final _discount = TextEditingController();
  final _selectedCategories = <String>{};
  bool _busy = false;
  String? _error;
  List<PurchaseOffer> _sent = const [];

  @override
  void initState() {
    super.initState();
    _sent = LocalPurchaseOfferStore.all();
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _href.dispose();
    _cta.dispose();
    _discount.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await LocalPurchaseOfferStore.create(
        title: _title.text,
        subtitle: _subtitle.text,
        href: _href.text,
        ctaLabel: _cta.text,
        categorySlugs: _selectedCategories.toList(),
        discountPct: int.tryParse(_discount.text.trim()) ?? 0,
      );
      if (!mounted) return;
      _title.clear();
      _subtitle.clear();
      setState(() {
        _sent = LocalPurchaseOfferStore.all();
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Offer sent to matching buyers on Dashboard → Offers'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e'.replaceFirst('Bad state: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Purchase offers')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            'Send an offer to users from what they already bought.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'Offer title',
              hintText: '15% off more fashion',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _subtitle,
            decoration: const InputDecoration(
              labelText: 'Message',
              hintText: 'Thanks for your last order — here is a follow-up deal',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _href,
            decoration: const InputDecoration(
              labelText: 'Link',
              helperText: 'Hubsom path such as /marketplace or /categories/fashion',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cta,
                  decoration: const InputDecoration(labelText: 'Button label'),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _discount,
                  decoration: const InputDecoration(labelText: '% off'),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Send to buyers of',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: HubsomColors.forest,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Leave empty to send to anyone who has made a purchase.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in hubsomCategories.take(12))
                FilterChip(
                  label: Text(c.name),
                  selected: _selectedCategories.contains(c.slug),
                  onSelected: (on) => setState(() {
                    if (on) {
                      _selectedCategories.add(c.slug);
                    } else {
                      _selectedCategories.remove(c.slug);
                    }
                  }),
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
            onPressed: _busy ? null : _send,
            child: Text(_busy ? 'Sending…' : 'Send offer'),
          ),
          const SizedBox(height: 28),
          Text(
            'Sent offers',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          if (_sent.isEmpty)
            const Text('No offers sent yet')
          else
            for (final offer in _sent)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(offer.title),
                subtitle: Text(
                  offer.hasTarget
                      ? 'Buyers of ${[
                          ...offer.categorySlugs,
                          ...offer.productIds,
                        ].join(', ')}'
                      : 'Anyone who has purchased',
                ),
              ),
        ],
      ),
    );
  }
}
