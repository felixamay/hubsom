import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/core_providers.dart';
import '../../core/services/payment_service.dart';
import '../../core/services/user_address_store.dart';
import '../../core/utils/money.dart';
import '../../models/user.dart';
import '../../widgets/gps_pin_card.dart';

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _selected = <String>{'mtn-momo'};
  bool _busy = false;
  String? _result;
  GeoLocation? _gps;
  UserAddress? _address;
  bool _gpsBusy = false;
  String? _gpsError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSavedPin());
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _applyPin(GeoLocation pin, {UserAddress? address}) async {
    _gps = pin;
    _address = address ??
        await UserAddressStore.fromAllowedGps(
          pin,
          phone: _phone.text.trim(),
        );
    _gpsError = null;
    await _quoteCart();
  }

  Future<void> _quoteCart() async {
    final pin = _gps;
    if (pin == null) return;
    final address =
        _address ?? await UserAddressStore.fromAllowedGps(pin);
    await ref.read(cartProvider.notifier).applyDestination(
      city: address.city,
      region: address.region,
      location: pin,
    );
  }

  void _loadSavedPin() {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    _name.text = user.name;
    _phone.text = user.phone ?? '';
    final saved = UserAddressStore.defaultAddress(user);
    if (saved?.location != null) {
      _applyPin(saved!.location!, address: saved).then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _useGps() async {
    setState(() {
      _gpsBusy = true;
      _gpsError = null;
    });
    try {
      final pin = await ref.read(locationServiceProvider).current();
      final user = ref.read(authStateProvider).valueOrNull;
      HubsomUser? next;
      if (user != null) {
        next = await UserAddressStore.saveAllowedGps(
          user: user,
          pin: pin,
          phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        );
        ref.read(authStateProvider.notifier).applyLocalUser(next);
      }
      if (!mounted) return;
      await _applyPin(
        pin,
        address: next == null ? null : UserAddressStore.defaultAddress(next),
      );
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() => _gpsError = '$e');
    } finally {
      if (mounted) setState(() => _gpsBusy = false);
    }
  }

  Future<void> _placeOrder() async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;
    if (_gps == null) {
      setState(() => _result = 'Allow your location so riders can navigate to you.');
      await _useGps();
      if (_gps == null) return;
    }
    setState(() { _busy = true; _result = null; });
    try {
      final address =
          _address ?? await UserAddressStore.fromAllowedGps(_gps!);
      await ref.read(cartProvider.notifier).applyDestination(
        city: address.city,
        region: address.region,
        location: _gps,
      );
      final cartQuoted = ref.read(cartProvider);
      final res = await ref.read(paymentServiceProvider).checkout(
        items: cartQuoted.map((e) => e.toJson()).toList(),
        shipping: {
          'recipientName': _name.text.trim(),
          'phone': _phone.text.trim(),
          'line1': address.line1,
          'city': address.city,
          'region': address.region,
          'location': _gps!.toJson(),
        },
        paymentMethods: _selected.toList(),
      );
      await ref.read(cartProvider.notifier).clear();
      final order = res['order'];
      final id = order is Map
          ? '${order['id'] ?? ''}'
          : '${res['id'] ?? 'ok'}';
      final zone = order is Map ? '${order['shipmentZoneLabel'] ?? ''}' : '';
      final ship = order is Map
          ? (order['shipmentFeeGhs'] as num?)?.toDouble() ?? 0
          : 0.0;
      setState(() {
        _result = ship > 0
            ? 'Order placed: $id. Shipment ${zone.isEmpty ? '' : '$zone · '}${formatGhs(ship)} sent to you.'
            : 'Order placed: $id';
      });
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
    final shipment = cart.fold<double>(0, (s, e) => s + e.shipmentLineTotal);
    final payable = subtotal + shipment;
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
          const SizedBox(height: 12),
          GpsPinCard(
            title: 'Your delivery address',
            pin: _gps,
            address: _address?.displayLine,
            busy: _gpsBusy,
            error: _gpsError,
            onUseLocation: _useGps,
          ),
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
          Text(
            shipment > 0
                ? 'Subtotal ${formatGhs(subtotal)} · Ship ${formatGhs(shipment)} · Total ${formatGhs(payable)}'
                : 'Subtotal ${formatGhs(subtotal)} · ${AppConstants.deliveryEstimate}',
          ),
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
