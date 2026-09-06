import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hubsom_app/core/auth/afia_access.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/providers/core_providers.dart';
import 'package:hubsom_app/core/repositories/auth_repository.dart';
import 'package:hubsom_app/core/services/api_client.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(_init);

  test('only the owner email unlocks Afia with the portal password', () async {
    expect(AfiaAccess.isOwnerEmail('felixames0808@gmail.com'), isTrue);
    expect(AfiaAccess.isOwnerEmail('FelixAmes0808@gmail.com'), isTrue);
    expect(AfiaAccess.isOwnerEmail('buyer@hubsom.test'), isFalse);
    expect(AfiaAccess.checkPassword('Newmoney@2025'), isTrue);
    expect(AfiaAccess.checkPassword('wrong'), isFalse);

    expect(await AfiaAccess.unlock(user: _other, password: 'Newmoney@2025'), isFalse);
    expect(AfiaAccess.isUnlocked(_other), isFalse);
    expect(await AfiaAccess.unlock(user: _owner, password: 'wrong'), isFalse);
    expect(await AfiaAccess.unlock(user: _owner, password: 'Newmoney@2025'), isTrue);
    expect(AfiaAccess.isUnlocked(_owner), isTrue);
    await AfiaAccess.lock();
    expect(AfiaAccess.isUnlocked(_owner), isFalse);
  });

  testWidgets('Afia stays hidden to other accounts', (tester) async {
    await tester.runAsync(() async {
      await LocalStore.setSessionToken('sess');
      await LocalStore.setUserJson(jsonEncode(_other.toJson()));
    });
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
    expect(find.text('Page not found'), findsOneWidget);
    expect(find.text('Password'), findsNothing);
    expect(find.text('Overview'), findsNothing);
  });

  testWidgets('owner unlocks Afia and sees the portal, not a menu leak',
      (tester) async {
    await tester.runAsync(() async {
      await LocalStore.setSessionToken('sess');
      await LocalStore.setUserJson(jsonEncode(_owner.toJson()));
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_LocalAuthRepository()),
        ],
        child: const MaterialApp(home: AfiaPortalPage()),
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 40));
    });
    await tester.pump();
    await tester.pump();

    expect(find.text('Page not found'), findsNothing);
    expect(find.text('Afia'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Newmoney@2025');
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 40));
    });
    await tester.pump();
    await tester.pump();

    expect(find.text('Overview'), findsWidgets);
    expect(find.text('Offers'), findsWidgets);
    expect(find.text('Orders'), findsWidgets);
    expect(find.text('Send purchase offers'), findsNothing);
  });
}
