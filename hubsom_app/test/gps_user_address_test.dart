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
import 'package:hubsom_app/core/services/ghana_places.dart';
import 'package:hubsom_app/core/services/local_store.dart';
import 'package:hubsom_app/core/services/location_service.dart';
import 'package:hubsom_app/core/services/place_lookup.dart';
import 'package:hubsom_app/core/services/user_address_store.dart';
import 'package:hubsom_app/features/account/addresses_page.dart';
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

const _buyer = HubsomUser(
  id: 'buyer-gps',
  email: 'buyer@hubsom.test',
  name: 'Ama Buyer',
  role: 'buyer',
);

const _kumasiPin = GeoLocation(
  latitude: 6.6885,
  longitude: -1.6244,
  source: 'gps',
);

const _dallasPin = GeoLocation(
  latitude: 32.7767,
  longitude: -96.7970,
  source: 'gps',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    AppConfig.load();
    CloudStore.useNetwork = false;
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('hubsom-gps-addr');
    Hive.init(dir.path);
    await LocalStore.init();
  });

  setUp(() {
    CloudStore.useNetwork = false;
    PlaceLookup.lookup = null;
  });

  tearDown(() {
    PlaceLookup.lookup = null;
  });

  test('nearest place uses GPS, not a default Accra fallback', () {
    final kumasi = GhanaPlaces.nearest(6.6885, -1.6244);
    expect(kumasi.city, 'Kumasi');
    expect(kumasi.region, 'Ashanti');

    final ocean = GhanaPlaces.nearest(0.1, 0.1);
    expect(ocean.city, isEmpty);
    expect(ocean.region, isEmpty);
  });

  test('displayLine shows a place name, not coordinates', () {
    final raw = UserAddress.fromJson({
      'id': 'addr-1',
      'label': 'Home',
      'line1': '5.11111, -0.22222',
      'city': 'Dallas',
      'region': 'Texas',
      'location': {'latitude': 32.7767, 'longitude': -96.7970, 'source': 'gps'},
    });
    expect(raw.displayLine, 'Dallas, Texas');
    expect(raw.displayLine, isNot(contains('32.7767')));
    expect(UserAddress.looksLikeCoordinates('32.77670, -96.79700'), isTrue);
    expect(UserAddress.looksLikeCoordinates('Dallas, Texas'), isFalse);
  });

  test('nominatim JSON becomes a Dallas address', () {
    final place = PlaceLookup.fromNominatimJson({
      'display_name':
          'Main Street, Dallas, Dallas County, Texas, United States',
      'address': {
        'road': 'Main Street',
        'city': 'Dallas',
        'state': 'Texas',
        'country': 'United States',
      },
    });
    expect(place, isNotNull);
    expect(place!.line1, 'Main Street, Dallas, Texas');
    expect(place.city, 'Dallas');
    expect(place.region, 'Texas');
    expect(place.displayLine, 'Main Street, Dallas, Texas');
  });

  test('saved address is the resolved place, not the GPS numbers', () async {
    final saved = await UserAddressStore.saveAllowedGps(
      user: _buyer,
      pin: _kumasiPin,
    );
    final address = UserAddressStore.defaultAddress(saved);
    expect(address, isNotNull);
    expect(address!.location?.latitude, 6.6885);
    expect(address.city, 'Kumasi');
    expect(address.line1, 'Kumasi, Ashanti');
    expect(address.displayLine, 'Kumasi, Ashanti');
    expect(address.displayLine, isNot(contains('6.6885')));
    expect(address.displayLine, isNot(contains('Accra')));
  });

  test('Dallas GPS saves Dallas, not coordinates or helper copy', () async {
    PlaceLookup.lookup = (_) async => const ResolvedPlace(
          line1: 'Dallas, Texas',
          city: 'Dallas',
          region: 'Texas',
        );
    final saved = await UserAddressStore.saveAllowedGps(
      user: _buyer,
      pin: _dallasPin,
    );
    final address = UserAddressStore.defaultAddress(saved)!;
    expect(address.displayLine, 'Dallas, Texas');
    expect(address.city, 'Dallas');
    expect(address.line1, isNot(contains(_dallasPin.coordinateLabel)));
  });

  testWidgets('addresses page saves the place name the GPS resolved',
      (tester) async {
    await tester.runAsync(() async {
      await LocalStore.setSessionToken('sess');
      await LocalStore.setUserJson(jsonEncode(_buyer.toJson()));
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_LocalAuthRepository()),
          locationServiceProvider.overrideWithValue(
            LocationService(fetcher: () async => _kumasiPin),
          ),
        ],
        child: const MaterialApp(home: AddressesPage()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Accra'), findsNothing);
    expect(find.text('This saved pin is your address — not a default Accra location.'),
        findsNothing);
    expect(find.text('Allow location'), findsWidgets);

    await tester.tap(find.text('Use GPS'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Delivery address'), findsOneWidget);
    expect(find.text('Save address'), findsOneWidget);

    await tester.tap(find.text('Allow location').last);
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 40));
    });
    await tester.pump();
    await tester.pump();
    expect(find.text('Kumasi, Ashanti'), findsWidgets);
    expect(find.textContaining('6.68850'), findsNothing);

    await tester.tap(find.text('Save address'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 40));
    });
    await tester.pump();
    await tester.pump();

    expect(find.text('Kumasi, Ashanti'), findsWidgets);
    expect(find.textContaining('Near Kumasi'), findsNothing);
    expect(find.textContaining(_kumasiPin.coordinateLabel), findsNothing);
    expect(find.text('Accra'), findsNothing);
  });

  test('checkout shipping uses the resolved place, not Accra or coordinates',
      () async {
    final address = await UserAddressStore.fromAllowedGps(_kumasiPin);
    expect(address.line1, 'Kumasi, Ashanti');
    expect(address.city, 'Kumasi');
    expect(address.region, 'Ashanti');
    expect(address.city, isNot('Accra'));
    expect(address.displayLine, isNot(contains('6.6885')));
    expect(address.location?.latitude, 6.6885);
  });
}
