import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_gate.dart';
import '../../core/auth/auth_routes.dart';
import '../../core/providers/core_providers.dart';
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

class _AuthRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authRefresh = _AuthRefresh();
  ref.listen(authStateProvider, (_, __) => authRefresh.ping());
  ref.onDispose(authRefresh.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    refreshListenable: authRefresh,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final loggingIn = auth.isLoading;
      if (loggingIn) return null;

      final user = auth.valueOrNull;
      final loc = state.uri.toString();
      final path = state.uri.path;
      final loggedIn = user != null;

      if (AuthRoutes.isAuthPage(path)) {
        if (loggedIn) {
          final callback = state.uri.queryParameters['callbackUrl'];
          if (callback != null &&
              callback.startsWith('/') &&
              !callback.startsWith('//')) {
            return callback;
          }
          return '/account';
        }
        return null;
      }

      if (!AuthRoutes.isPublic(path) && !loggedIn) {
        final callback = Uri.encodeComponent(loc);
        return '/auth/sign-in?callbackUrl=$callback';
      }

      if (loggedIn && AuthRoutes.requiresSeller(path)) {
        if (!AuthRoutes.isSellerRole(user.role)) {
          return '/account';
        }
      }

      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/', builder: (_, __) => const HomePage()),
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
              GoRoute(path: '/sell', builder: (_, __) => const SellPage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/account',
                builder: (_, __) => const AuthGate(child: AccountPage()),
                routes: [
                  GoRoute(
                    path: 'profile',
                    builder: (_, __) => const AuthGate(child: ProfilePage()),
                  ),
                  GoRoute(
                    path: 'addresses',
                    builder: (_, __) => const AuthGate(child: AddressesPage()),
                  ),
                  GoRoute(
                    path: 'following',
                    builder: (_, __) => const AuthGate(child: FollowingPage()),
                  ),
                  GoRoute(
                    path: 'saved',
                    builder: (_, __) => const AuthGate(child: SavedPage()),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (_, __) => const AuthGate(child: DashboardPage()),
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
        builder: (_, state) => LiveRoomPage(
          streamId: state.pathParameters['id']!,
          hostMode: state.uri.queryParameters['host'] == '1',
        ),
      ),
      GoRoute(
        path: '/products/:id',
        builder: (_, state) =>
            ProductDetailPage(productId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/stores/:slug',
        builder: (_, state) => StorePage(slug: state.pathParameters['slug']!),
      ),
      GoRoute(path: '/cart', builder: (_, __) => const CartPage()),
      GoRoute(
        path: '/checkout',
        builder: (_, __) => const AuthGate(
          message: 'Sign in to checkout securely',
          child: CheckoutPage(),
        ),
      ),
      GoRoute(
        path: '/messages',
        builder: (_, __) => const AuthGate(
          message: 'Sign in to view your messages',
          child: MessagesPage(),
        ),
      ),
      GoRoute(
        path: '/messages/:userId',
        builder: (_, state) => AuthGate(
          message: 'Sign in to chat',
          child: ChatThreadPage(userId: state.pathParameters['userId']!),
        ),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const AuthGate(child: NotificationsPage()),
      ),
      GoRoute(
        path: '/wallet',
        builder: (_, __) => const AuthGate(
          message: 'Sign in to access your wallet',
          child: WalletPage(),
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const AuthGate(child: SettingsPage()),
      ),
      GoRoute(path: '/auth/sign-in', builder: (_, __) => const SignInPage()),
      GoRoute(path: '/auth/sign-up', builder: (_, __) => const SignUpPage()),
      GoRoute(
        path: '/seller',
        builder: (_, __) => const AuthGate(
          requireSeller: true,
          child: SellerHubPage(),
        ),
      ),
      GoRoute(
        path: '/seller/store',
        builder: (_, __) =>
            const AuthGate(requireSeller: true, child: SellerStorePage()),
      ),
      GoRoute(
        path: '/seller/orders',
        builder: (_, __) =>
            const AuthGate(requireSeller: true, child: SellerOrdersPage()),
      ),
      GoRoute(
        path: '/seller/analytics',
        builder: (_, __) =>
            const AuthGate(requireSeller: true, child: SellerAnalyticsPage()),
      ),
      GoRoute(
        path: '/seller/go-live',
        builder: (_, __) =>
            const AuthGate(requireSeller: true, child: SellerGoLivePage()),
      ),
      GoRoute(
        path: '/seller/products/new',
        builder: (_, state) => AuthGate(
          requireSeller: true,
          child: SellerProductNewPage(
            returnTo: state.uri.queryParameters['returnTo'],
          ),
        ),
      ),
      GoRoute(
        path: '/driver/track/:shipmentId',
        builder: (_, state) => AuthGate(
          requireSeller: true,
          message: 'Sign in as a seller to track deliveries',
          child: DeliveryMapPage(shipmentId: state.pathParameters['shipmentId']!),
        ),
      ),
    ],
  );
});
