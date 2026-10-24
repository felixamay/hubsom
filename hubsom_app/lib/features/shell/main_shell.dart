import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../widgets/hubsom_logo.dart';
import '../../widgets/responsive_scaffold.dart';

/// Mirrors Next.js MobileTabBar: Home / Categories / Sell / Account / Dashboard
class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _tabs = [
    (path: '/', label: 'Home', icon: Icons.home_outlined, selected: Icons.home),
    (path: '/categories', label: 'Categories', icon: Icons.grid_view_outlined, selected: Icons.grid_view),
    (path: '/sell', label: 'Sell', icon: Icons.storefront_outlined, selected: Icons.storefront),
    (path: '/account', label: 'Account', icon: Icons.person_outline, selected: Icons.person),
    (path: '/dashboard', label: 'Dashboard', icon: Icons.insights_outlined, selected: Icons.insights),
  ];

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(cartProvider).fold<int>(0, (s, e) => s + e.quantity);
    final wide = ResponsiveScaffold.isWide(context);

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _onTap,
              labelType: NavigationRailLabelType.all,
              backgroundColor: Colors.white,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: HubsomLogo(height: 40),
              ),
              destinations: [
                for (final t in _tabs)
                  NavigationRailDestination(
                    icon: Icon(t.icon),
                    selectedIcon: Icon(t.selected),
                    label: Text(t.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                children: [
                  _TopBar(cartCount: cartCount),
                  Expanded(child: navigationShell),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const HubsomLogo(height: 32),
        actions: [
          IconButton(
            tooltip: 'Search',
            onPressed: () => context.push('/marketplace'),
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: 'Messages',
            onPressed: () => context.push('/messages'),
            icon: const Icon(Icons.chat_bubble_outline),
          ),
          IconButton(
            tooltip: 'Cart',
            onPressed: () => context.push('/cart'),
            icon: Badge(
              isLabelVisible: cartCount > 0,
              label: Text('$cartCount'),
              child: const Icon(Icons.shopping_bag_outlined),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onTap,
        destinations: [
          for (final t in _tabs)
            NavigationDestination(
              icon: Icon(t.icon),
              selectedIcon: Icon(t.selected, color: HubsomColors.forest),
              label: t.label,
            ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.cartCount});
  final int cartCount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  readOnly: true,
                  onTap: () => context.push('/marketplace'),
                  decoration: const InputDecoration(
                    hintText: 'Search Hubsom marketplace…',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => context.push('/live'),
                icon: const Icon(Icons.videocam_outlined),
                tooltip: 'Live',
              ),
              IconButton(
                onPressed: () => context.push('/messages'),
                icon: const Icon(Icons.chat_bubble_outline),
              ),
              IconButton(
                onPressed: () => context.push('/cart'),
                icon: Badge(
                  isLabelVisible: cartCount > 0,
                  label: Text('$cartCount'),
                  child: const Icon(Icons.shopping_bag_outlined),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
