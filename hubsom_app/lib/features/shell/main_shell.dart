import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../widgets/hubsom_logo.dart';
import '../../widgets/responsive_scaffold.dart';

/// Mirrors Next.js MobileTabBar: Home / Categories / Sell / Timeline / Dashboard
class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _tabs = [
    (path: '/', label: 'Home', icon: Icons.home_outlined, selected: Icons.home),
    (path: '/categories', label: 'Categories', icon: Icons.grid_view_outlined, selected: Icons.grid_view),
    (path: '/sell', label: 'Sell', icon: Icons.storefront_outlined, selected: Icons.storefront),
    (path: '/timeline', label: 'Timeline', icon: Icons.dynamic_feed_outlined, selected: Icons.dynamic_feed),
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
    final cartCount = ref.watch(cartCountProvider);
    final unreadMessages = ref.watch(unreadMessagesCountProvider);
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
                child: HubsomLogo(height: 36, showWordmark: true),
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
                  _TopBar(cartCount: cartCount, unreadMessages: unreadMessages),
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
        title: const HubsomLogo(height: 30, showWordmark: true),
        actions: [
          IconButton(
            tooltip: 'Search',
            onPressed: () => context.push('/marketplace'),
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: 'Messages',
            onPressed: () => context.push('/messages'),
            icon: Badge(
              isLabelVisible: unreadMessages > 0,
              label: Text('$unreadMessages'),
              child: const Icon(Icons.chat_bubble_outline),
            ),
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
          PopupMenuButton<String>(
            tooltip: 'Menu',
            icon: const Icon(Icons.menu),
            onSelected: (value) {
              switch (value) {
                case 'account':
                  context.push('/account');
                case 'settings':
                  context.push('/settings');
                case 'notifications':
                  context.push('/notifications');
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'account',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.person_outline),
                  title: Text('Account'),
                ),
              ),
              PopupMenuItem(
                value: 'notifications',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.notifications_outlined),
                  title: Text('Notifications'),
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.settings_outlined),
                  title: Text('Settings'),
                ),
              ),
            ],
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
  const _TopBar({required this.cartCount, required this.unreadMessages});
  final int cartCount;
  final int unreadMessages;

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
                tooltip: 'Messages',
                onPressed: () => context.push('/messages'),
                icon: Badge(
                  isLabelVisible: unreadMessages > 0,
                  label: Text('$unreadMessages'),
                  child: const Icon(Icons.chat_bubble_outline),
                ),
              ),
              IconButton(
                onPressed: () => context.push('/cart'),
                icon: Badge(
                  isLabelVisible: cartCount > 0,
                  label: Text('$cartCount'),
                  child: const Icon(Icons.shopping_bag_outlined),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Menu',
                icon: const Icon(Icons.menu),
                onSelected: (value) {
                  switch (value) {
                    case 'account':
                      context.push('/account');
                    case 'settings':
                      context.push('/settings');
                    case 'notifications':
                      context.push('/notifications');
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'account',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.person_outline),
                      title: Text('Account'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'notifications',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.notifications_outlined),
                      title: Text('Notifications'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'settings',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.settings_outlined),
                      title: Text('Settings'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
