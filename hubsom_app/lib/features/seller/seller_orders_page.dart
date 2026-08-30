import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/core_providers.dart';
import '../../core/utils/money.dart';
import '../../models/order.dart';
import '../../models/shipment.dart';

class SellerOrdersPage extends ConsumerStatefulWidget {
  const SellerOrdersPage({super.key});
  @override
  ConsumerState<SellerOrdersPage> createState() => _SellerOrdersPageState();
}

class _SellerOrdersPageState extends ConsumerState<SellerOrdersPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<Order> orders = [];
  List<Shipment> shipments = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final repo = ref.read(orderRepositoryProvider);
      final o = await repo.sellerOrders();
      final s = await repo.listShipments();
      if (!mounted) return;
      setState(() { orders = o; shipments = s; loading = false; });
    } catch (e) {
      if (mounted) setState(() { error = '$e'; loading = false; });
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
        bottom: TabBar(controller: _tabs, tabs: const [Tab(text: 'Orders'), Tab(text: 'Shipments')]),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!))
              : TabBarView(controller: _tabs, children: [
                  ListView.builder(
                    itemCount: orders.length,
                    itemBuilder: (_, i) {
                      final o = orders[i];
                      return ListTile(
                        title: Text(o.id, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('${o.status} · ${formatGhs(o.subtotalGhs)} · ${o.lines.length} lines'),
                        trailing: o.shipping?.location != null
                            ? IconButton(
                                tooltip: 'Locate buyer',
                                icon: const Icon(Icons.map_outlined),
                                onPressed: () => context.push('/driver/track/${o.id}'),
                              )
                            : null,
                      );
                    },
                  ),
                  ListView.builder(
                    itemCount: shipments.length,
                    itemBuilder: (_, i) {
                      final s = shipments[i];
                      return ListTile(
                        title: Text(s.id, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('${s.status} · ${s.items.length} items · ${s.destination.city}'),
                        trailing: Wrap(spacing: 4, children: [
                          TextButton(
                            onPressed: () async {
                              try {
                                await ref.read(orderRepositoryProvider).offerToHubers(s.id);
                                await _load();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Hubers offers sent to signed-up drivers',
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        e.toString().replaceFirst('Bad state: ', ''),
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            child: const Text('Hubers'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.map_outlined),
                            onPressed: () => context.push('/driver/track/${s.id}'),
                          ),
                        ]),
                      );
                    },
                  ),
                ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final paid = orders.where((o) => o.status == 'paid').map((o) => o.id).toList();
          if (paid.isEmpty) return;
          await ref.read(orderRepositoryProvider).createShipment({'orderIds': paid});
          await _load();
        },
        label: const Text('Consolidate'),
        icon: const Icon(Icons.merge_type),
      ),
    );
  }
}
