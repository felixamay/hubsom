import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../widgets/hubsom_logo.dart';
import '../../widgets/responsive_scaffold.dart';

/// Footer: Home / Categories / Sell / Timeline / Dashboard
/// Header ☰: formal Hubsom links + Account hub (Account is not a footer tab).
class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _tabs = [
    (path: '/', label: 'Home', icon: Icons.home_outlined, selected: Icons.home),
    (
      path: '/categories',
      label: 'Categories',
      icon: Icons.grid_view_outlined,
      selected: Icons.grid_view
    ),
    (
      path: '/sell',
      label: 'Sell',
      icon: Icons.storefront_outlined,
      selected: Icons.storefront
    ),
    (
      path: '/timeline',
      label: 'Timeline',
      icon: Icons.dynamic_feed_outlined,
      selected: Icons.dynamic_feed
    ),
    (
      path: '/dashboard',
      label: 'Dashboard',
      icon: Icons.insights_outlined,
      selected: Icons.insights
    ),
  ];

  /// Formal SiteHeader links first, then Account destinations.
  static const _formalItems = <(String value, IconData icon, String label)>[
    ('live', Icons.videocam_outlined, 'Live'),
    ('marketplace', Icons.storefront_outlined, 'Marketplace'),
    ('auctions', Icons.gavel, 'Auctions'),
    ('flash', Icons.bolt_outlined, 'Flash Sales'),
    ('sell', Icons.add_business_outlined, 'Sell'),
  ];

  static const _accountItems = <(String value, IconData icon, String label)>[
    ('account', Icons.person_outline, 'Account'),
    ('profile', Icons.badge_outlined, 'Profile'),
    ('saved', Icons.favorite_border, 'Saved products'),
    ('following', Icons.people_outline, 'Following'),
    ('followers', Icons.groups_outlined, 'Followers'),
    ('wallet', Icons.account_balance_wallet_outlined, 'Wallet'),
    ('videos', Icons.play_circle_outline, 'Watch videos'),
    ('messages', Icons.chat_bubble_outline, 'Messages'),
    ('notifications', Icons.notifications_outlined, 'Notifications'),
    ('settings', Icons.settings_outlined, 'Settings'),
  ];

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  void _onMenuSelected(BuildContext context, String value) {
    final path = switch (value) {
      'live' => '/live',
      'marketplace' => '/marketplace',
      'auctions' => '/auctions',
      'flash' => '/flash-sales',
      'sell' => '/sell',
      'account' => '/account',
      'profile' => '/account/profile',
      'saved' => '/account/saved',
      'following' => '/account/following',
      'followers' => '/account/followers',
      'wallet' => '/wallet',
      'videos' => '/videos',
      'messages' => '/messages',
      'notifications' => '/notifications',
      'settings' => '/settings',
      _ => null,
    };
    if (path == null) return;
    // Root-level go so Account is not trapped inside the shell branch stack.
    context.go(path);
  }

  List<PopupMenuEntry<String>> _buildMenu() {
    return [
      const PopupMenuItem<String>(
        enabled: false,
        child: Text(
          'Browse',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: HubsomColors.forest,
            fontSize: 12,
          ),
        ),
      ),
      for (final item in _formalItems)
        PopupMenuItem<String>(
          value: item.$1,
          child: Row(
            children: [
              Icon(item.$2, size: 22, color: HubsomColors.forest),
              const SizedBox(width: 12),
              Text(item.$3),
            ],
          ),
        ),
      const PopupMenuDivider(),
      const PopupMenuItem<String>(
        enabled: false,
        child: Text(
          'Account',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: HubsomColors.forest,
            fontSize: 12,
          ),
        ),
      ),
      for (final item in _accountItems)
        PopupMenuItem<String>(
          value: item.$1,
          child: Row(
            children: [
              Icon(item.$2, size: 22, color: HubsomColors.forest),
              const SizedBox(width: 12),
              Text(item.$3),
            ],
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(cartCountProvider);
    final unreadMessages = ref.watch(unreadMessagesCountProvider);
    final wide = ResponsiveScaffold.isWide(context);
    final menu = _buildMenu();

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
                  _TopBar(
                    cartCount: cartCount,
                    unreadMessages: unreadMessages,
                    menuEntries: menu,
                    onMenuSelected: (v) => _onMenuSelected(context, v),
                  ),
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
            onPressed: () => context.go('/marketplace'),
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: 'Live',
            onPressed: () => context.go('/live'),
            icon: const Icon(Icons.videocam_outlined),
          ),
          IconButton(
            tooltip: 'Messages',
            onPressed: () => context.go('/messages'),
            icon: Badge(
              isLabelVisible: unreadMessages > 0,
              label: Text('$unreadMessages'),
              child: const Icon(Icons.chat_bubble_outline),
            ),
          ),
          IconButton(
            tooltip: 'Cart',
            onPressed: () => context.go('/cart'),
            icon: Badge(
              isLabelVisible: cartCount > 0,
              label: Text('$cartCount'),
              child: const Icon(Icons.shopping_bag_outlined),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Menu',
            icon: const Icon(Icons.menu),
            onSelected: (value) => _onMenuSelected(context, value),
            itemBuilder: (_) => menu,
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
  const _TopBar({
    required this.cartCount,
    required this.unreadMessages,
    required this.menuEntries,
    required this.onMenuSelected,
  });

  final int cartCount;
  final int unreadMessages;
  final List<PopupMenuEntry<String>> menuEntries;
  final ValueChanged<String> onMenuSelected;

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
                  onTap: () => context.go('/marketplace'),
                  decoration: const InputDecoration(
                    hintText: 'Search Hubsom marketplace…',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => context.go('/live'),
                icon: const Icon(Icons.videocam_outlined),
                tooltip: 'Live',
              ),
              IconButton(
                tooltip: 'Messages',
                onPressed: () => context.go('/messages'),
                icon: Badge(
                  isLabelVisible: unreadMessages > 0,
                  label: Text('$unreadMessages'),
                  child: const Icon(Icons.chat_bubble_outline),
                ),
              ),
              IconButton(
                onPressed: () => context.go('/cart'),
                icon: Badge(
                  isLabelVisible: cartCount > 0,
                  label: Text('$cartCount'),
                  child: const Icon(Icons.shopping_bag_outlined),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Menu',
                icon: const Icon(Icons.menu),
                onSelected: onMenuSelected,
                itemBuilder: (_) => menuEntries,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
