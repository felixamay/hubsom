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

  /// Browse links everyone may see. Sell and Dashboard stay AuthGate locked.
  static const guestBrowseItems = <(String value, IconData icon, String label)>[
    ('live', Icons.videocam_outlined, 'Live'),
    ('marketplace', Icons.storefront_outlined, 'Marketplace'),
    ('auctions', Icons.gavel, 'Auctions'),
    ('flash', Icons.bolt_outlined, 'Flash Sales'),
    ('sell', Icons.add_business_outlined, 'Sell'),
    ('dashboard', Icons.insights_outlined, 'Dashboard'),
  ];

  static const signedInBrowseItems = guestBrowseItems;

  static List<String> footerLabels({required bool signedIn}) =>
      _tabs.map((t) => t.label).toList();

  static const accountMenuItems = <(String value, IconData icon, String label)>[
    ('account', Icons.person_outline, 'Account'),
    ('profile', Icons.badge_outlined, 'Profile'),
    ('saved', Icons.favorite_border, 'Saved products'),
    ('following', Icons.people_outline, 'Following'),
    ('followers', Icons.groups_outlined, 'Followers'),
    ('wallet', Icons.account_balance_wallet_outlined, 'Wallet'),
    ('gifts', Icons.card_giftcard_outlined, 'Buy gift points'),
    ('videos', Icons.play_circle_outline, 'Watch videos'),
    ('messages', Icons.chat_bubble_outline, 'Messages'),
    ('notifications', Icons.notifications_outlined, 'Notifications'),
    ('settings', Icons.settings_outlined, 'Settings'),
  ];

  static int _visibleFooterIndex({
    required int shellIndex,
    required bool signedIn,
  }) {
    return shellIndex;
  }

  void _onFooterTap(
    BuildContext context,
    WidgetRef ref,
    int visibleIndex, {
    required bool signedIn,
  }) {
    _onTap(context, ref, visibleIndex);
  }

  void _onTap(BuildContext context, WidgetRef ref, int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
    // Timeline is an IndexedStack child — refresh when the tab is opened so
    // shop videos synced on Home appear immediately.
    if (index == 3) {
      ref.read(timelineTabTickProvider.notifier).state++;
    }
  }

  Future<void> _onMenuSelected(
    BuildContext context,
    WidgetRef ref,
    String value,
  ) async {
    if (value == 'logout') {
      await ref.read(authStateProvider.notifier).signOut();
      if (context.mounted) context.go('/');
      return;
    }
    final path = switch (value) {
      'live' => '/live',
      'marketplace' => '/marketplace',
      'auctions' => '/auctions',
      'flash' => '/flash-sales',
      'sell' => '/sell',
      'dashboard' => '/dashboard',
      'account' => '/account',
      'profile' => '/account/profile',
      'saved' => '/account/saved',
      'following' => '/account/following',
      'followers' => '/account/followers',
      'wallet' => '/wallet',
      'gifts' => '/gifts',
      'videos' => '/videos',
      'messages' => '/messages',
      'notifications' => '/notifications',
      'settings' => '/settings',
      'signin' => '/auth/sign-in',
      _ => null,
    };
    if (path == null) return;
    // Root-level go so Account is not trapped inside the shell branch stack.
    context.go(path);
  }

  static List<(String value, IconData icon, String label)> browseItems({
    required bool signedIn,
  }) =>
      signedIn ? signedInBrowseItems : guestBrowseItems;

  static List<(String value, IconData icon, String label)> menuDestinations({
    required bool signedIn,
  }) =>
      [
        ...browseItems(signedIn: signedIn),
        if (signedIn) ...accountMenuItems,
      ];

  List<PopupMenuEntry<String>> _buildMenu({required bool signedIn}) {
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
      for (final item in browseItems(signedIn: signedIn))
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
      if (signedIn) ...[
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
        for (final item in accountMenuItems)
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
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 22, color: HubsomColors.forest),
              SizedBox(width: 12),
              Text('Log out'),
            ],
          ),
        ),
      ] else ...[
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'signin',
          child: Row(
            children: [
              Icon(Icons.login, size: 22, color: HubsomColors.forest),
              SizedBox(width: 12),
              Text('Sign in'),
            ],
          ),
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(cartCountProvider);
    final unreadMessages = ref.watch(unreadMessagesCountProvider);
    final signedIn = ref.watch(authStateProvider).valueOrNull != null;
    final wide = ResponsiveScaffold.isWide(context);
    final menu = _buildMenu(signedIn: signedIn);
    const footerTabs = _tabs;
    final selectedFooter = _visibleFooterIndex(
      shellIndex: navigationShell.currentIndex,
      signedIn: signedIn,
    );

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selectedFooter,
              onDestinationSelected: (i) => _onFooterTap(
                context,
                ref,
                i,
                signedIn: signedIn,
              ),
              labelType: NavigationRailLabelType.all,
              backgroundColor: Colors.white,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: HubsomLogo(height: 36, showWordmark: true),
              ),
              destinations: [
                for (final t in footerTabs)
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
                    showMessages: signedIn,
                    menuEntries: menu,
                    onMenuSelected: (v) => _onMenuSelected(context, ref, v),
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
          if (signedIn)
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
            onSelected: (value) => _onMenuSelected(context, ref, value),
            itemBuilder: (_) => menu,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedFooter,
        onDestinationSelected: (i) =>
            _onFooterTap(context, ref, i, signedIn: signedIn),
        destinations: [
          for (final t in footerTabs)
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
    required this.showMessages,
    required this.menuEntries,
    required this.onMenuSelected,
  });

  final int cartCount;
  final int unreadMessages;
  final bool showMessages;
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
              if (showMessages)
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
