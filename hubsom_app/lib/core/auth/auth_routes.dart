/// Route access policy for Hubsom Flutter.
///
/// Public routes are browse-only. All account, commerce, messaging, seller,
/// wallet, and dispatch features require an authenticated session.
abstract final class AuthRoutes {
  static const publicExact = <String>{
    '/',
    '/categories',
    '/marketplace',
    '/flash-sales',
    '/auctions',
    '/live',
    '/cart',
    '/auth/sign-in',
    '/auth/sign-up',
  };

  static const publicPrefixes = <String>[
    '/categories/',
    '/products/',
    '/stores/',
    '/live/',
    '/auth/',
  ];

  static const sellerPrefixes = <String>[
    '/seller',
    '/sell',
  ];

  static bool isPublic(String location) {
    final path = location.split('?').first;
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

  static bool isSellerRole(String? role) =>
      role == 'seller' || role == 'both' || role == 'admin';
}
