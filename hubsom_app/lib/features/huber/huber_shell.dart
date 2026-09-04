import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/hubsom_colors.dart';

class HuberShell extends StatelessWidget {
  const HuberShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _tabs = [
    (path: '/huber', label: 'Home', icon: Icons.home_outlined, selected: Icons.home),
    (path: '/huber/hub', label: 'Hub Now', icon: Icons.bolt_outlined, selected: Icons.bolt),
    (path: '/huber/earnings', label: 'Earnings', icon: Icons.insights_outlined, selected: Icons.insights),
    (path: '/huber/wallet', label: 'Wallet', icon: Icons.account_balance_wallet_outlined, selected: Icons.account_balance_wallet),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Hail',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: HubsomColors.huberNavy,
              ),
        ),
        actions: [
          IconButton(
            tooltip: 'Marketplace',
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.storefront_outlined),
          ),
          IconButton(
            tooltip: 'Account',
            onPressed: () => context.push('/account'),
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
        destinations: [
          for (final t in _tabs)
            NavigationDestination(
              icon: Icon(t.icon),
              selectedIcon: Icon(t.selected, color: HubsomColors.huberNavy),
              label: t.label,
            ),
        ],
      ),
    );
  }
}
