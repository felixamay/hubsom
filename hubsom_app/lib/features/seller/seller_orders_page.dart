import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/core_providers.dart';
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

  Future<void> _offerHubers(Shipment shipment) async {
    setState(() => _busyId = shipment.id);
    try {
      await ref.read(orderRepositoryProvider).offerToHubers(shipment.id);
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
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
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
          await ref
              .read(orderRepositoryProvider)
              .createShipment({'orderIds': paid});
          await _load();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Shipment created — offer to Hubers')),
          );
          _tabs.animateTo(1);
        },
        label: const Text('Consolidate'),
        icon: const Icon(Icons.merge_type),
      ),
    );
  }
}
