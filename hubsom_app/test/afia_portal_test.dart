import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hubsom_app/core/auth/afia_access.dart';
import 'package:hubsom_app/core/auth/auth_routes.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/providers/core_providers.dart';
import 'package:hubsom_app/core/repositories/auth_repository.dart';
import 'package:hubsom_app/core/repositories/catalog_repository.dart';
import 'package:hubsom_app/core/services/api_client.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/core/services/local_promotion_store.dart';
import 'package:hubsom_app/core/services/local_store.dart';
import 'package:hubsom_app/features/admin/afia_portal_page.dart';
import 'package:hubsom_app/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

ApiClient _unusedApi() => ApiClient(
      dio: Dio(
        BaseOptions(
          baseUrl: 'http://127.0.0.1:1',
          connectTimeout: const Duration(milliseconds: 1),
          receiveTimeout: const Duration(milliseconds: 1),
        ),
      ),
    );

class _LocalAuthRepository extends AuthRepository {
  _LocalAuthRepository() : super(_unusedApi());

  @override
  Future<HubsomUser?> fetchProfile() async => currentUser();
}

const _owner = HubsomUser(
  id: 'u-afia',
  email: 'felixames0808@gmail.com',
  name: 'Felix',
  role: 'admin',
);

const _other = HubsomUser(
  id: 'u-buyer',
  email: 'buyer@hubsom.test',
  name: 'Ama Buyer',
  role: 'buyer',
);

Future<void> _init() async {
  AppConfig.load();
  CloudStore.useNetwork = false;
  SharedPreferences.setMockInitialValues({});
  final dir = Directory.systemTemp.createTempSync('hubsom-afia');
  Hive.init(dir.path);
  await LocalStore.init();
  await AfiaAccess.lock();
}

Future<void> _pumpPortal(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_LocalAuthRepository()),
      ],
      child: const MaterialApp(home: AfiaPortalPage()),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(_init);

  test('Afia paths canonicalize to /afia and stay public', () {
    expect(AfiaAccess.matchesPath('/Afia'), isTrue);
    expect(AfiaAccess.matchesPath('/afia'), isTrue);
    expect(AfiaAccess.matchesPath('/AFIA/'), isTrue);
    expect(AfiaAccess.matchesPath('/hubsom-admin'), isTrue);
    expect(AfiaAccess.matchesPath('/account'), isFalse);
    expect(AfiaAccess.path, '/afia');
    expect(AfiaAccess.canonicalRedirect('/afia'), isNull);
    expect(AfiaAccess.canonicalRedirect('/Afia'), '/afia');
    expect(AfiaAccess.canonicalRedirect('/Afia/'), '/afia');
    expect(AfiaAccess.canonicalRedirect('/hubsom-admin'), '/afia');
    expect(AfiaAccess.canonicalRedirect('/hubsom-admin/'), '/afia');
    expect(AuthRoutes.isPublic('/Afia'), isTrue);
    expect(AuthRoutes.isPublic('/afia'), isTrue);
    expect(AuthRoutes.isPublic('/hubsom-admin'), isTrue);
    expect(AuthRoutes.requiresAdmin('/afia'), isFalse);
    expect(AuthRoutes.requiresAdmin('/Afia'), isFalse);
  });

  test('only the owner email unlocks Afia with the portal password', () async {
    expect(AfiaAccess.isOwnerEmail('felixames0808@gmail.com'), isTrue);
    expect(AfiaAccess.isOwnerEmail('FelixAmes0808@gmail.com'), isTrue);
    expect(AfiaAccess.isOwnerEmail('buyer@hubsom.test'), isFalse);
    expect(AfiaAccess.checkPassword('Newmoney@2025'), isTrue);
    expect(AfiaAccess.checkPassword('wrong'), isFalse);

    expect(await AfiaAccess.unlock(user: _other, password: 'Newmoney@2025'), isFalse);
    expect(AfiaAccess.isUnlocked(_other), isFalse);
    expect(await AfiaAccess.unlock(email: 'buyer@hubsom.test', password: 'Newmoney@2025'), isFalse);
    expect(await AfiaAccess.unlock(user: _owner, password: 'wrong'), isFalse);
    expect(await AfiaAccess.unlock(email: _owner.email, password: 'Newmoney@2025'), isTrue);
    expect(AfiaAccess.isUnlocked(), isTrue);
    await AfiaAccess.lock();
    expect(AfiaAccess.isUnlocked(), isFalse);
  });

  test('promotions persist and list by placement', () async {
    await LocalPromotionStore.create(
      title: 'Weekend live',
      href: '/live',
      placements: ['landing', 'marketplace'],
    );
    expect(LocalPromotionStore.all(), hasLength(1));
    expect(LocalPromotionStore.forPlacement('landing').single.title, 'Weekend live');
    expect(LocalPromotionStore.forPlacement('marketplace'), hasLength(1));
    expect(LocalPromotionStore.forPlacement('product'), isEmpty);

    final catalog = CatalogRepository(_unusedApi());
    final landing = await catalog.listPromotions('landing');
    expect(landing.single.title, 'Weekend live');
  });

  testWidgets('a saved Afia unlock opens the admin shell', (tester) async {
    await tester.runAsync(() async {
      await AfiaAccess.unlock(
        email: 'felixames0808@gmail.com',
        password: 'Newmoney@2025',
      );
    });
    await _pumpPortal(tester);
    expect(find.text('Overview'), findsWidgets);
    expect(find.text('Promotions'), findsWidgets);
    expect(find.text('Sign in'), findsNothing);
  });

  testWidgets('Afia URL shows a real admin login without a Hubsom session',
      (tester) async {
    await _pumpPortal(tester);
    expect(find.text('Hubsom Admin'), findsOneWidget);
    expect(find.text('Afia console'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Page not found'), findsNothing);
    expect(find.text('Overview'), findsNothing);
  });

  testWidgets('wrong Afia credentials stay on the login page', (tester) async {
    await _pumpPortal(tester);
    await tester.enterText(find.byType(TextField).at(0), 'buyer@hubsom.test');
    await tester.enterText(find.byType(TextField).at(1), 'Newmoney@2025');
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 40));
    });
    await tester.pump();
    expect(find.text('Email or password is not valid for this portal.'), findsOneWidget);
    expect(find.text('Overview'), findsNothing);
  });

  testWidgets('owner email and password open the integrated admin portal',
      (tester) async {
    await _pumpPortal(tester);
    await tester.enterText(find.byType(TextField).at(0), 'felixames0808@gmail.com');
    await tester.enterText(find.byType(TextField).at(1), 'Newmoney@2025');
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 40));
    });
    await tester.pump();
    await tester.pump();

    expect(find.text('Hubsom Admin'), findsWidgets);
    expect(find.text('Overview'), findsWidgets);
    expect(find.text('Accounts'), findsWidgets);
    expect(find.text('Payouts'), findsWidgets);
    expect(find.text('Controls'), findsWidgets);
    expect(find.text('Promotions'), findsWidgets);
    expect(find.text('Send purchase offers'), findsNothing);
  });
}
