import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/core/services/local_store.dart';
import 'package:hubsom_app/features/dashboard/dashboard_page.dart';
import 'package:hubsom_app/features/shell/main_shell.dart';
import 'package:hubsom_app/features/wallet/gift_points_page.dart';
import 'package:hubsom_app/models/live_gift.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    AppConfig.load();
    CloudStore.useNetwork = false;
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('hubsom-buy-gift');
    Hive.init(dir.path);
    await LocalStore.init();
  });

  test('header menu lists Buy gift points', () {
    expect(
      MainShell.accountMenuItems.any(
        (item) => item.$1 == 'gifts' && item.$3 == 'Buy gift points',
      ),
      isTrue,
    );
  });

  testWidgets('dashboard shows gift points and buy gift', (tester) async {
    final router = GoRouter(
      initialLocation: '/dashboard',
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (_, __) => const Scaffold(body: DashboardPage()),
        ),
        GoRoute(path: '/gifts', builder: (_, __) => const GiftPointsPage()),
        GoRoute(
          path: '/auth/sign-in',
          builder: (_, __) => const Scaffold(body: Text('Sign in')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gift points'), findsOneWidget);
    expect(find.text('Buy gift points'), findsOneWidget);

    await tester.tap(find.text('Buy gift points'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('buy gift page lists point packs', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: GiftPointsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Buy gift points'), findsWidgets);
    expect(find.text('${GiftCatalog.packs.first.points} points'), findsOneWidget);
    expect(find.text('Buy'), findsWidgets);
  });
}
