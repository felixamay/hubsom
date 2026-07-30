import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../account/account_page.dart';
import '../account/addresses_page.dart';
import '../account/following_page.dart';
import '../account/profile_page.dart';
import '../account/saved_page.dart';
import '../auctions/auctions_page.dart';
import '../authentication/sign_in_page.dart';
import '../authentication/sign_up_page.dart';
import '../cart/cart_page.dart';
import '../categories/categories_page.dart';
import '../categories/category_detail_page.dart';
import '../chat/chat_thread_page.dart';
import '../chat/messages_page.dart';
import '../checkout/checkout_page.dart';
import '../dashboard/dashboard_page.dart';
import '../driver/delivery_map_page.dart';
import '../flash_sales/flash_sales_page.dart';
import '../home/home_page.dart';
import '../live/live_room_page.dart';
import '../live/live_list_page.dart';
import '../marketplace/marketplace_page.dart';
import '../notifications/notifications_page.dart';
import '../products/product_detail_page.dart';
import '../sell/sell_page.dart';
import '../seller/seller_analytics_page.dart';
import '../seller/seller_go_live_page.dart';
import '../seller/seller_hub_page.dart';
import '../seller/seller_orders_page.dart';
import '../seller/seller_product_new_page.dart';
import '../seller/seller_store_page.dart';
import '../settings/settings_page.dart';
import '../stores/store_page.dart';
import '../wallet/wallet_page.dart';
import 'main_shell.dart';

final _rootKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, __) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/categories',
                builder: (_, __) => const CategoriesPage(),
                routes: [
                  GoRoute(
                    path: ':slug',
                    builder: (_, state) =>
                        CategoryDetailPage(slug: state.pathParameters['slug']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/sell',
                builder: (_, __) => const SellPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/account',
                builder: (_, __) => const AccountPage(),
                routes: [
                  GoRoute(path: 'profile', builder: (_, __) => const ProfilePage()),
                  GoRoute(path: 'addresses', builder: (_, __) => const AddressesPage()),
                  GoRoute(path: 'following', builder: (_, __) => const FollowingPage()),
                  GoRoute(path: 'saved', builder: (_, __) => const SavedPage()),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (_, __) => const DashboardPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(path: '/marketplace', builder: (_, __) => const MarketplacePage()),
      GoRoute(path: '/flash-sales', builder: (_, __) => const FlashSalesPage()),
      GoRoute(path: '/auctions', builder: (_, __) => const AuctionsPage()),
      GoRoute(path: '/live', builder: (_, __) => const LiveListPage()),
      GoRoute(
        path: '/live/:id',
        builder: (_, state) => LiveRoomPage(streamId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/products/:id',
        builder: (_, state) => ProductDetailPage(productId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/stores/:slug',
        builder: (_, state) => StorePage(slug: state.pathParameters['slug']!),
      ),
      GoRoute(path: '/cart', builder: (_, __) => const CartPage()),
      GoRoute(path: '/checkout', builder: (_, __) => const CheckoutPage()),
      GoRoute(path: '/messages', builder: (_, __) => const MessagesPage()),
      GoRoute(
        path: '/messages/:userId',
        builder: (_, state) => ChatThreadPage(userId: state.pathParameters['userId']!),
      ),
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsPage()),
      GoRoute(path: '/wallet', builder: (_, __) => const WalletPage()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
      GoRoute(path: '/auth/sign-in', builder: (_, __) => const SignInPage()),
      GoRoute(path: '/auth/sign-up', builder: (_, __) => const SignUpPage()),
      GoRoute(path: '/seller', builder: (_, __) => const SellerHubPage()),
      GoRoute(path: '/seller/store', builder: (_, __) => const SellerStorePage()),
      GoRoute(path: '/seller/orders', builder: (_, __) => const SellerOrdersPage()),
      GoRoute(path: '/seller/analytics', builder: (_, __) => const SellerAnalyticsPage()),
      GoRoute(path: '/seller/go-live', builder: (_, __) => const SellerGoLivePage()),
      GoRoute(
        path: '/seller/products/new',
        builder: (_, __) => const SellerProductNewPage(),
      ),
      GoRoute(
        path: '/driver/track/:shipmentId',
        builder: (_, state) =>
            DeliveryMapPage(shipmentId: state.pathParameters['shipmentId']!),
      ),
    ],
  );
});
