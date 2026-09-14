import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/core_providers.dart';
import '../../core/services/local_commerce_store.dart';
import '../../core/services/shipment_fee.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../core/utils/money.dart';
import '../../models/order.dart';
import '../../models/shipment.dart';

const _orderStatuses = <String>[
  'paid',
  'processing',
  'shipped',
  'delivered',
  'cancelled',
];

class SellerOrdersPage extends ConsumerStatefulWidget {
  const SellerOrdersPage({super.key});
  @override
  ConsumerState<SellerOrdersPage> createState() => _SellerOrdersPageState();
}

class _SellerOrdersPageState extends ConsumerState<SellerOrdersPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<Order> orders = [];
  List<Shipment> shipments = [];
  bool loading = true;
  String? error;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final repo = ref.read(orderRepositoryProvider);
      final o = await repo.sellerOrders();
      final s = await repo.listShipments();
      if (!mounted) return;
      setState(() {
        orders = o;
        shipments = s;
        loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '$e';
          loading = false;
        });
      }
    }
  }

  Future<void> _setOrderStatus(Order order, String status) async {
    setState(() => _busyId = order.id);
    try {
      await ref.read(orderRepositoryProvider).updateOrder(order.id, {
        'status': status,
      });
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order marked $status')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Bad state: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _shipShipment(Shipment shipment) async {
    setState(() => _busyId = shipment.id);
    try {
      await ref.read(orderRepositoryProvider).markShipmentShipped(shipment.id);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            shipment.assignedHuberName == null
                ? 'Shipment marked shipped'
                : 'Shipped with ${shipment.assignedHuberName}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Bad state: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  double _feeFromOrders(Iterable<Order> orders) {
    final stored = Order.shipmentFeeFor(orders);
    if (stored > 0) return stored;
    var total = 0.0;
    for (final order in orders) {
      for (final line in order.lines) {
        final product = LocalCommerceStore.getProduct(line.productId);
        if (product != null && product.hasShipmentFee) {
          final quote = ShipmentFee.quote(
            product,
            city: order.shipping?.city,
            region: order.shipping?.region,
            location: order.shipping?.location,
          );
          total += quote.feeGhs * line.quantity;
        }
      }
    }
    return total;
  }

  double _feeFromShipment(Shipment shipment) {
    if ((shipment.offeredFeeGhs ?? 0) > 0) return shipment.offeredFeeGhs!;
    final linked = orders.where((o) => shipment.orderIds.contains(o.id));
    return _feeFromOrders(linked);
  }

  Future<_DeliveryDraft?> _collectDeliveryDetails({
    required bool includeFee,
    OrderShipping? initial,
    double? initialFee,
    String title = 'Delivery details',
  }) {
    return showModalBottomSheet<_DeliveryDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _DeliveryDetailsSheet(
        includeFee: includeFee,
        initial: initial,
        initialFee: initialFee,
        title: title,
      ),
    );
  }

  Future<void> _saveOrderDelivery(Order order) async {
    final draft = await _collectDeliveryDetails(
      includeFee: false,
      initial: order.shipping,
      title: 'Customer delivery details',
    );
    if (draft == null) return;
    setState(() => _busyId = order.id);
    try {
      await ref.read(orderRepositoryProvider).updateOrder(order.id, {
        'shipping': draft.toShipping().toJson(),
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Bad state: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _saveShipmentDelivery(Shipment shipment) async {
    final draft = await _collectDeliveryDetails(
      includeFee: true,
      initial: shipment.destination,
      initialFee: _feeFromShipment(shipment),
      title: 'Shipment & rider offer',
    );
    if (draft == null) return;
    setState(() => _busyId = shipment.id);
    try {
      await ref.read(orderRepositoryProvider).updateShipment(shipment.id, {
        'destination': draft.toShipping().toJson(),
        'offeredFeeGhs': draft.feeGhs,
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Bad state: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _offerHubers(Shipment shipment) async {
    var ready = shipment;
    if (!ready.hasRiderOfferDetails) {
      final draft = await _collectDeliveryDetails(
        includeFee: true,
        initial: ready.destination,
        initialFee: _feeFromShipment(ready),
        title: 'Add fee, location and phone for riders',
      );
      if (draft == null) return;
      ready = await ref.read(orderRepositoryProvider).updateShipment(
        ready.id,
        {
          'destination': draft.toShipping().toJson(),
          'offeredFeeGhs': draft.feeGhs,
        },
      );
    }
    setState(() => _busyId = ready.id);
    try {
      await ref.read(orderRepositoryProvider).offerToHubers(ready.id);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hubers offers sent to signed-up drivers')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Bad state: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders & shipments'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'Orders'), Tab(text: 'Shipments')],
        ),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!))
              : TabBarView(
                  controller: _tabs,
                  children: [
                    orders.isEmpty
                        ? const Center(child: Text('No orders yet'))
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                            itemCount: orders.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final o = orders[i];
                              final busy = _busyId == o.id;
                              return Material(
                                color: HubsomColors.mist,
                                borderRadius: BorderRadius.circular(14),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        o.lines.isNotEmpty
                                            ? o.lines.first.name
                                            : o.id,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        [
                                          formatGhs(o.subtotalGhs),
                                          if (o.effectiveShipmentFeeGhs > 0)
                                            'ship ${formatGhs(o.effectiveShipmentFeeGhs)}',
                                          if (o.buyerName != null &&
                                              o.buyerName!.isNotEmpty)
                                            o.buyerName!,
                                          if (o.streamId != null)
                                            'live auction',
                                        ].join(' · '),
                                        style: const TextStyle(
                                          color: Colors.black54,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: InputDecorator(
                                              decoration: const InputDecoration(
                                                labelText: 'Order status',
                                                border: OutlineInputBorder(),
                                                isDense: true,
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 8,
                                                ),
                                              ),
                                              child: DropdownButtonHideUnderline(
                                                child: DropdownButton<String>(
                                                  isExpanded: true,
                                                  value: _orderStatuses
                                                          .contains(o.status)
                                                      ? o.status
                                                      : 'paid',
                                                  items: [
                                                    for (final s
                                                        in _orderStatuses)
                                                      DropdownMenuItem(
                                                        value: s,
                                                        child: Text(s),
                                                      ),
                                                  ],
                                                  onChanged: busy
                                                      ? null
                                                      : (v) {
                                                          if (v == null ||
                                                              v == o.status) {
                                                            return;
                                                          }
                                                          _setOrderStatus(o, v);
                                                        },
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (o.shipping?.location != null) ...[
                                            const SizedBox(width: 8),
                                            IconButton(
                                              tooltip: 'Locate buyer',
                                              icon: const Icon(
                                                Icons.map_outlined,
                                              ),
                                              onPressed: () => context.push(
                                                '/driver/track/${o.id}',
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        o.shipping?.hasCustomerContact == true
                                            ? '${o.shipping!.phone} · ${o.shipping!.locationLabel}'
                                            : 'Add customer location and phone for riders',
                                        style: TextStyle(
                                          color: o.shipping?.hasCustomerContact ==
                                                  true
                                              ? Colors.black87
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .error,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: TextButton.icon(
                                          onPressed: busy
                                              ? null
                                              : () => _saveOrderDelivery(o),
                                          icon: const Icon(
                                            Icons.edit_location_alt_outlined,
                                          ),
                                          label: Text(
                                            o.shipping?.hasCustomerContact ==
                                                    true
                                                ? 'Edit delivery details'
                                                : 'Add delivery details',
                                          ),
                                        ),
                                      ),
                                      if (busy)
                                        const Padding(
                                          padding: EdgeInsets.only(top: 8),
                                          child: LinearProgressIndicator(),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                    shipments.isEmpty
                        ? const Center(
                            child: Text(
                              'No shipments yet. Consolidate paid orders first.',
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                            itemCount: shipments.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final s = shipments[i];
                              final busy = _busyId == s.id;
                              return Material(
                                color: HubsomColors.mist,
                                borderRadius: BorderRadius.circular(14),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.id,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        [
                                          s.status,
                                          '${s.items.length} items',
                                          s.destination.city,
                                          if (s.assignedHuberName != null)
                                            s.assignedHuberName!,
                                        ].join(' · '),
                                        style: const TextStyle(
                                          color: Colors.black54,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        [
                                          if ((s.offeredFeeGhs ?? 0) > 0)
                                            'Fee ${formatGhs(s.offeredFeeGhs!)}'
                                          else
                                            'No shipment fee',
                                          if (s.destination.phone.isNotEmpty)
                                            s.destination.phone
                                          else
                                            'No customer phone',
                                          if (s.destination.locationLabel
                                              .isNotEmpty)
                                            s.destination.locationLabel
                                          else
                                            'No customer location',
                                        ].join(' · '),
                                        style: TextStyle(
                                          color: s.hasRiderOfferDetails
                                              ? Colors.black87
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .error,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          OutlinedButton(
                                            onPressed: busy
                                                ? null
                                                : () => _saveShipmentDelivery(s),
                                            child: const Text('Edit offer details'),
                                          ),
                                          if (s.status == 'ready' ||
                                              s.status == 'offering')
                                            FilledButton.tonal(
                                              onPressed: busy
                                                  ? null
                                                  : () => _offerHubers(s),
                                              child: Text(
                                                s.status == 'offering'
                                                    ? 'Re-offer Hubers'
                                                    : 'Offer to Hubers',
                                              ),
                                            ),
                                          if (s.status == 'assigned')
                                            FilledButton(
                                              onPressed: busy
                                                  ? null
                                                  : () => _shipShipment(s),
                                              child: const Text('Ship order'),
                                            ),
                                          if (s.status == 'shipped' ||
                                              s.status == 'out_for_delivery')
                                            Chip(
                                              avatar: const Icon(
                                                Icons.local_shipping,
                                                size: 16,
                                              ),
                                              label: Text(
                                                s.status == 'shipped'
                                                    ? 'Shipped — rider en route'
                                                    : 'Out for delivery',
                                              ),
                                            ),
                                          if (s.status == 'delivered')
                                            const Chip(
                                              avatar: Icon(
                                                Icons.check_circle,
                                                size: 16,
                                                color: Colors.green,
                                              ),
                                              label: Text('Delivered by rider'),
                                            ),
                                          IconButton(
                                            tooltip: 'Track',
                                            icon: const Icon(
                                              Icons.map_outlined,
                                            ),
                                            onPressed: () => context.push(
                                              '/driver/track/${s.id}',
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (busy)
                                        const Padding(
                                          padding: EdgeInsets.only(top: 8),
                                          child: LinearProgressIndicator(),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final paid = orders
              .where((o) => o.status == 'paid' || o.status == 'processing')
              .map((o) => o.id)
              .toList();
          if (paid.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No paid/processing orders to consolidate'),
              ),
            );
            return;
          }
          final seed = orders.firstWhere(
            (o) => paid.contains(o.id),
            orElse: () => orders.first,
          );
          final paidOrders = orders.where((o) => paid.contains(o.id));
          final draft = await _collectDeliveryDetails(
            includeFee: true,
            initial: seed.shipping,
            initialFee: _feeFromOrders(paidOrders),
            title: 'Shipment fee, location and phone',
          );
          if (draft == null) return;
          final messenger = ScaffoldMessenger.of(context);
          await ref.read(orderRepositoryProvider).createShipment({
            'orderIds': paid,
            'destination': draft.toShipping().toJson(),
            'offeredFeeGhs': draft.feeGhs,
          });
          await _load();
          if (!mounted) return;
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Shipment created — offer these details to riders'),
            ),
          );
          _tabs.animateTo(1);
        },
        label: const Text('Consolidate'),
        icon: const Icon(Icons.merge_type),
      ),
    );
  }
}

class _DeliveryDraft {
  const _DeliveryDraft({
    required this.recipientName,
    required this.phone,
    required this.line1,
    required this.city,
    required this.region,
    this.feeGhs,
  });

  final String recipientName;
  final String phone;
  final String line1;
  final String city;
  final String region;
  final double? feeGhs;

  OrderShipping toShipping() => OrderShipping(
        recipientName: recipientName,
        phone: phone,
        line1: line1,
        city: city,
        region: region,
      );
}

class _DeliveryDetailsSheet extends StatefulWidget {
  const _DeliveryDetailsSheet({
    required this.includeFee,
    required this.title,
    this.initial,
    this.initialFee,
  });

  final bool includeFee;
  final String title;
  final OrderShipping? initial;
  final double? initialFee;

  @override
  State<_DeliveryDetailsSheet> createState() => _DeliveryDetailsSheetState();
}

class _DeliveryDetailsSheetState extends State<_DeliveryDetailsSheet> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _line1;
  late final TextEditingController _city;
  late final TextEditingController _region;
  late final TextEditingController _fee;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _name = TextEditingController(text: initial?.recipientName ?? '');
    _phone = TextEditingController(text: initial?.phone ?? '');
    _line1 = TextEditingController(text: initial?.line1 ?? '');
    _city = TextEditingController(
      text: initial?.city.isNotEmpty == true
          ? initial!.city
          : AppConstants.defaultCity,
    );
    _region = TextEditingController(
      text: initial?.region.isNotEmpty == true
          ? initial!.region
          : AppConstants.defaultRegion,
    );
    _fee = TextEditingController(
      text: widget.initialFee != null && widget.initialFee! > 0
          ? widget.initialFee!.toStringAsFixed(0)
          : '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _line1.dispose();
    _city.dispose();
    _region.dispose();
    _fee.dispose();
    super.dispose();
  }

  void _submit() {
    final phone = _phone.text.trim();
    final line1 = _line1.text.trim();
    final city = _city.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'Add the customer phone number');
      return;
    }
    if (line1.isEmpty && city.isEmpty) {
      setState(() => _error = 'Add the customer location');
      return;
    }
    double? fee;
    if (widget.includeFee) {
      fee = double.tryParse(_fee.text.trim());
      if (fee == null || fee <= 0) {
        setState(() => _error = 'Add a shipment fee for riders');
        return;
      }
    }
    Navigator.pop(
      context,
      _DeliveryDraft(
        recipientName: _name.text.trim().isEmpty
            ? 'Customer'
            : _name.text.trim(),
        phone: phone,
        line1: line1.isEmpty ? city : line1,
        city: city.isEmpty ? AppConstants.defaultCity : city,
        region: _region.text.trim().isEmpty
            ? AppConstants.defaultRegion
            : _region.text.trim(),
        feeGhs: fee,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Riders see the fee, customer location, and phone on the offer.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Customer name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Customer phone'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _line1,
              decoration: const InputDecoration(
                labelText: 'Customer location / address',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _city,
                    decoration: const InputDecoration(labelText: 'City'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _region,
                    decoration: const InputDecoration(labelText: 'Region'),
                  ),
                ),
              ],
            ),
            if (widget.includeFee) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _fee,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Shipment fee (GHS)',
                  helperText: 'This is the payout riders see on the offer',
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submit,
              child: const Text('Save for riders'),
            ),
          ],
        ),
      ),
    );
  }
}
