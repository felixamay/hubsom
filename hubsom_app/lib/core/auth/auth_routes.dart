/// Route access policy for Hubsom Flutter.
///
/// Public routes are browse-only. All account, commerce, messaging, seller,
/// wallet, Huber driver, and dispatch features require an authenticated session.
abstract final class AuthRoutes {
  static const publicExact = <String>{
    '/',
    '/categories',
    '/marketplace',
    '/flash-sales',
    '/auctions',
    '/live',
    '/timeline',
    '/videos',
    '/cart',
    '/auth/sign-in',
    '/auth/sign-up',
  };

  /// Account, wallet, messages, and seller tools — menu + route locked.
  static const signedInExact = <String>{
    '/account',
    '/account/profile',
    '/account/addresses',
    '/account/following',
    '/account/followers',
    '/account/saved',
    '/wallet',
    '/wallet/gifts',
    '/gifts',
    '/messages',
    '/notifications',
    '/settings',
    '/settings/password',
    '/settings/passkeys',
    '/dashboard',
    '/sell',
    '/checkout',
    '/videos/upload',
  };

  static const publicPrefixes = <String>[
    '/categories/',
    '/products/',
    '/stores/',
    '/live/',
    '/videos/',
    '/auth/',
  ];

  static const sellerPrefixes = <String>[
    '/seller',
    '/sell',
  ];

  static bool isPublic(String location) {
    final path = location.split('?').first;
    if (signedInExact.contains(path) ||
        path.startsWith('/account/') ||
        path.startsWith('/wallet/') ||
        path.startsWith('/messages/') ||
        path.startsWith('/seller') ||
        path.startsWith('/sell/') ||
        path.startsWith('/huber')) {
      return false;
    }
    if (publicExact.contains(path)) return true;
    for (final p in publicPrefixes) {
      if (path.startsWith(p)) return true;
    }
    return false;
  }

  static bool isAuthPage(String location) {
    final path = location.split('?').first;
    return path == '/auth/sign-in' || path == '/auth/sign-up';
  }

  static bool requiresSeller(String location) {
    final path = location.split('?').first;
    if (path == '/sell') return false; // sell landing can show CTA
    return path == '/seller' || path.startsWith('/seller/');
  }

  static bool requiresHuber(String location) {
    final path = location.split('?').first;
    return path == '/huber' || path.startsWith('/huber/');
  }

  static bool isSellerRole(String? role) =>
      role == 'seller' || role == 'both' || role == 'admin';

  static bool isHuberRole(String? role, {String? huberId}) =>
      role == 'huber' ||
      role == 'driver' ||
      role == 'admin' ||
      (huberId != null && huberId.isNotEmpty);

  /// After sign-in / sign-up: Huber accounts land in the driver hub unless
  /// they were sent to a specific non-account page (checkout, etc.).
  static String homeForUser(
    String? role, {
    String? callback,
    String? huberId,
  }) {
    final driver = isHuberRole(role, huberId: huberId);
    final cb = callback;
    if (cb != null && cb.startsWith('/') && !cb.startsWith('//')) {
      if (driver && (cb == '/account' || cb == '/' || cb.isEmpty)) {
        return '/huber';
      }
      return cb;
    }
    return driver ? '/huber' : '/account';
  }
}
