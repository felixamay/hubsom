import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/providers/core_providers.dart';
import 'package:hubsom_app/core/repositories/auth_repository.dart';
import 'package:hubsom_app/core/services/api_client.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/core/services/local_store.dart';
import 'package:hubsom_app/core/services/location_service.dart';
import 'package:hubsom_app/core/services/place_lookup.dart';
import 'package:hubsom_app/core/services/user_address_store.dart';
import 'package:hubsom_app/features/checkout/checkout_page.dart';
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

const _accraPin = GeoLocation(
  latitude: 5.6037,
  longitude: -0.1870,
  source: 'gps',
);

const _kumasiPin = GeoLocation(
  latitude: 6.6885,
  longitude: -1.6244,
  source: 'gps',
);

const _accraHome = UserAddress(
  id: 'addr-home',
  label: 'Home',
  line1: 'East Legon, Accra',
  city: 'Accra',
  region: 'Greater Accra',
  phone: '0240000000',
  isDefault: true,
  location: _accraPin,
);

const _buyerHome = HubsomUser(
  id: 'buyer-gps-checkout',
  email: 'buyer-checkout@hubsom.test',
  name: 'Ama Buyer',
  role: 'buyer',
  phone: '0240000000',
  addresses: [_accraHome],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    AppConfig.load();
    CloudStore.useNetwork = false;
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('hubsom-checkout-addr');
    Hive.init(dir.path);
    await LocalStore.init();
  });

  setUp(() {
    CloudStore.useNetwork = false;
    PlaceLookup.lookup = (pin) async => PlaceLookup.fromLocal(pin);
  });

  tearDown(() {
    PlaceLookup.lookup = null;
  });

  testWidgets(
      'opening checkout keeps a saved Home even if GPS is now somewhere else',
      (tester) async {
    await tester.runAsync(() async {
      CloudStore.useNetwork = false;
      await LocalStore.setSessionToken('sess');
      await LocalStore.setUserJson(jsonEncode(_buyerHome.toJson()));
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_LocalAuthRepository()),
          locationServiceProvider.overrideWithValue(
            LocationService(fetcher: () async => _kumasiPin),
          ),
        ],
        child: const MaterialApp(home: CheckoutPage()),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();

    expect(find.text('East Legon, Accra'), findsWidgets);
    expect(find.textContaining('Kumasi'), findsNothing);

    final persisted = HubsomUser.fromJson(
      jsonDecode(LocalStore.userJson!) as Map<String, dynamic>,
    );
    final address = UserAddressStore.defaultAddress(persisted)!;
    expect(address.city, 'Accra');
    expect(address.line1, 'East Legon, Accra');
    expect(address.location?.latitude, 5.6037);
  });
}
