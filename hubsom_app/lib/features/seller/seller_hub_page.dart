import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/hubsom_colors.dart';

class SellerHubPage extends StatelessWidget {
  const SellerHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final links = [
      ('Store', '/seller/store', Icons.store),
      ('New product', '/seller/products/new', Icons.add_box_outlined),
      ('Orders & shipments', '/seller/orders', Icons.local_shipping_outlined),
      ('Go live', '/seller/go-live', Icons.videocam),
      ('Analytics', '/seller/analytics', Icons.insights),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Seller hub')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Manage your Hubsom store', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('Orders, Hubers dispatch, live shopping, and catalog — preserved from the web seller tools.'),
          const SizedBox(height: 16),
          ...links.map((e) => ListTile(
                leading: Icon(e.$3, color: HubsomColors.forest),
                title: Text(e.$1),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(e.$2),
              )),
        ],
      ),
    );
  }
}
