import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/core/services/local_store.dart';
import 'package:hubsom_app/features/settings/change_password_page.dart';
import 'package:hubsom_app/features/settings/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    AppConfig.load();
    CloudStore.useNetwork = false;
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('hubsom-settings');
    Hive.init(dir.path);
    await LocalStore.init();
  });

  setUp(() {
    CloudStore.useNetwork = false;
  });

  testWidgets('settings lists change password', (tester) async {
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (_, __) => const SettingsPage(),
        ),
        GoRoute(
          path: '/settings/password',
          builder: (_, __) => const ChangePasswordPage(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pump();

    expect(find.text('Change password'), findsOneWidget);
    await tester.tap(find.text('Change password'));
    await tester.pumpAndSettle();

    expect(find.text('Update password'), findsOneWidget);
    expect(find.text('Current password'), findsOneWidget);
    expect(find.text('New password'), findsOneWidget);
    expect(find.text('Confirm new password'), findsOneWidget);
  });

  testWidgets('change password form validates empty and mismatched fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ChangePasswordPage()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Update password'));
    await tester.pump();
    expect(find.text('Enter your current password'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'password1');
    await tester.enterText(find.byType(TextFormField).at(1), 'short');
    await tester.tap(find.text('Update password'));
    await tester.pump();
    expect(find.text('Min 8 characters'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(1), 'password1');
    await tester.enterText(find.byType(TextFormField).at(2), 'password2');
    await tester.tap(find.text('Update password'));
    await tester.pump();
    expect(find.text('Choose a different new password'), findsOneWidget);
    expect(find.text('Passwords do not match'), findsOneWidget);
  });
}
