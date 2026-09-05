import 'package:flutter_test/flutter_test.dart';
import 'package:hubsom_app/core/auth/auth_routes.dart';
import 'package:hubsom_app/features/shell/main_shell.dart';

void main() {
  test('guest footer includes Sell and Dashboard', () {
    final guest = MainShell.footerLabels(signedIn: false);
    expect(guest, contains('Sell'));
    expect(guest, contains('Dashboard'));
    expect(guest, contains('Home'));
    expect(
      MainShell.footerLabels(signedIn: true),
      contains('Dashboard'),
    );
  });

  test('guest menu shows sell but hides account, wallet, and gifts', () {
    final guest = MainShell.menuDestinations(signedIn: false);
    final values = guest.map((e) => e.$1).toSet();
    expect(values.contains('live'), isTrue);
    expect(values.contains('marketplace'), isTrue);
    expect(values.contains('sell'), isTrue);
    expect(values.contains('dashboard'), isTrue);
    expect(values.contains('wallet'), isFalse);
    expect(values.contains('gifts'), isFalse);
    expect(values.contains('account'), isFalse);
    expect(values.contains('messages'), isFalse);
    expect(values.contains('settings'), isFalse);
  });

  test('signed-in menu includes sell and sensitive account items', () {
    final signedIn = MainShell.menuDestinations(signedIn: true);
    final values = signedIn.map((e) => e.$1).toSet();
    expect(values.contains('sell'), isTrue);
    expect(values.contains('dashboard'), isTrue);
    expect(values.contains('wallet'), isTrue);
    expect(values.contains('gifts'), isTrue);
    expect(values.contains('account'), isTrue);
    expect(values.contains('messages'), isTrue);
    expect(
      MainShell.accountMenuItems.any((item) => item.$1 == 'gifts'),
      isTrue,
    );
  });

  test('sensitive routes are not public', () {
    expect(AuthRoutes.isPublic('/wallet'), isFalse);
    expect(AuthRoutes.isPublic('/wallet/gifts'), isFalse);
    expect(AuthRoutes.isPublic('/gifts'), isFalse);
    expect(AuthRoutes.isPublic('/account'), isFalse);
    expect(AuthRoutes.isPublic('/account/profile'), isFalse);
    expect(AuthRoutes.isPublic('/messages'), isFalse);
    expect(AuthRoutes.isPublic('/dashboard'), isFalse);
    expect(AuthRoutes.isPublic('/sell'), isFalse);
    expect(
      MainShell.menuDestinations(signedIn: false).any((e) => e.$1 == 'sell'),
      isTrue,
    );
    expect(AuthRoutes.isPublic('/videos/upload'), isFalse);
    expect(AuthRoutes.isPublic('/seller/go-live'), isFalse);
    expect(AuthRoutes.isPublic('/sell/go-live'), isFalse);
    expect(AuthRoutes.isPublic('/checkout'), isFalse);
    expect(AuthRoutes.isPublic('/huber'), isFalse);
    expect(AuthRoutes.isPublic('/settings'), isFalse);
    expect(AuthRoutes.isPublic('/'), isTrue);
    expect(AuthRoutes.isPublic('/live'), isTrue);
    expect(AuthRoutes.isPublic('/marketplace'), isTrue);
  });
}
