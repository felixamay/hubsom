import 'package:flutter/material.dart';

import 'hubsom_logo.dart';

/// Phone/tablet AppBar that keeps Search off the Hubsom wordmark.
///
/// Action count scales with width. The title is clipped and scaled so it
/// cannot paint into the icon row on Plus/Max phones.
class HubsomPhoneAppBar extends StatelessWidget implements PreferredSizeWidget {
  const HubsomPhoneAppBar({
    super.key,
    required this.width,
    required this.signedIn,
    required this.cartCount,
    required this.unreadMessages,
    required this.unreadNotifications,
    required this.menuEntries,
    required this.onSearch,
    required this.onLive,
    required this.onNotifications,
    required this.onMessages,
    required this.onCart,
    required this.onMenuSelected,
  });

  final double width;
  final bool signedIn;
  final int cartCount;
  final int unreadMessages;
  final int unreadNotifications;
  final List<PopupMenuEntry<String>> menuEntries;
  final VoidCallback onSearch;
  final VoidCallback onLive;
  final VoidCallback onNotifications;
  final VoidCallback onMessages;
  final VoidCallback onCart;
  final ValueChanged<String> onMenuSelected;

  /// Live / inbox sit in ☰ below this width (large phones).
  static bool inlineExtras(double width) => width >= 520;

  static const iconDensity = VisualDensity(horizontal: -2, vertical: -2);

  static Widget title({required double width}) {
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: HubsomLogo(
          height: width < 360 ? 26 : 30,
          showWordmark: width >= 320,
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final extras = inlineExtras(width);
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 8,
      title: title(width: width),
      actionsPadding: const EdgeInsets.only(right: 4),
      actions: [
        IconButton(
          tooltip: 'Search',
          visualDensity: iconDensity,
          onPressed: onSearch,
          icon: const Icon(Icons.search),
        ),
        if (extras)
          IconButton(
            tooltip: 'Live',
            visualDensity: iconDensity,
            onPressed: onLive,
            icon: const Icon(Icons.videocam_outlined),
          ),
        if (signedIn && extras)
          IconButton(
            tooltip: 'Notifications',
            visualDensity: iconDensity,
            onPressed: onNotifications,
            icon: Badge(
              isLabelVisible: unreadNotifications > 0,
              label: Text('$unreadNotifications'),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
        if (signedIn && extras)
          IconButton(
            tooltip: 'Messages',
            visualDensity: iconDensity,
            onPressed: onMessages,
            icon: Badge(
              isLabelVisible: unreadMessages > 0,
              label: Text('$unreadMessages'),
              child: const Icon(Icons.chat_bubble_outline),
            ),
          ),
        IconButton(
          tooltip: 'Cart',
          visualDensity: iconDensity,
          onPressed: onCart,
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
    );
  }
}
