import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/core_providers.dart';
import '../../core/services/payment_service.dart';
import '../../core/utils/money.dart';

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _line1 = TextEditingController();
  final _city = TextEditingController(text: AppConstants.defaultCity);
  final _region = TextEditingController(text: AppConstants.defaultRegion);
  final _selected = <String>{'mtn-momo'};
  bool _busy = false;
  String? _result;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _line1.dispose();
    _city.dispose();
    _region.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;
    setState(() { _busy = true; _result = null; });
    try {
      final res = await ref.read(paymentServiceProvider).checkout(
        items: cart.map((e) => e.toJson()).toList(),
        shipping: {
          'recipientName': _name.text.trim(),
          'phone': _phone.text.trim(),
          'line1': _line1.text.trim(),
          'city': _city.text.trim(),
          'region': _region.text.trim(),
        },
        paymentMethods: _selected.toList(),
      );
      await ref.read(cartProvider.notifier).clear();
      setState(() => _result = 'Order placed: ${res['order']?['id'] ?? res['id'] ?? 'ok'}');
    } catch (e) {
      setState(() => _result = 'Checkout failed: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final subtotal = cart.fold<double>(0, (s, e) => s + e.lineTotal);
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Delivery', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Recipient name')),
          const SizedBox(height: 8),
          TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone'), keyboardType: TextInputType.phone),
          const SizedBox(height: 8),
          TextField(controller: _line1, decoration: const InputDecoration(labelText: 'Address line')),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: _city, decoration: const InputDecoration(labelText: 'City'))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _region, decoration: const InputDecoration(labelText: 'Region'))),
          ]),
          const SizedBox(height: 20),
          Text('Payment', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...PaymentService.supportedMethods.map((m) => CheckboxListTile(
                value: _selected.contains(m),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _selected.add(m);
                  } else {
                    _selected.remove(m);
                  }
                }),
                title: Text(m),
                contentPadding: EdgeInsets.zero,
                dense: true,
              )),
          const SizedBox(height: 12),
          Text('Subtotal ${formatGhs(subtotal)} · ${AppConstants.deliveryEstimate}'),
          if (_result != null) ...[
            const SizedBox(height: 12),
            Text(_result!),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy || cart.isEmpty ? null : _placeOrder,
            child: Text(_busy ? 'Processing…' : 'Place order'),
          ),
          TextButton(onPressed: () => context.pop(), child: const Text('Back to cart')),
        ],
      ),
    );
  }
}
