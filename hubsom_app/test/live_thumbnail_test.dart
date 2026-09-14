import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/providers/core_providers.dart';
import 'package:hubsom_app/core/repositories/live_repository.dart';
import 'package:hubsom_app/core/services/api_client.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/core/services/local_blob_store.dart';
import 'package:hubsom_app/core/services/local_commerce_store.dart';
import 'package:hubsom_app/core/services/local_store.dart';
import 'package:hubsom_app/core/services/storage_media.dart';
import 'package:hubsom_app/features/home/home_page.dart';
import 'package:hubsom_app/features/live/live_list_page.dart';
import 'package:hubsom_app/features/seller/seller_go_live_page.dart';
import 'package:hubsom_app/models/stream.dart';
import 'package:hubsom_app/models/user.dart';
import 'package:hubsom_app/widgets/hubsom_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _seller = HubsomUser(
  id: 'seller-1',
  email: 'seller@hubsom.test',
  name: 'Ama Host',
  role: 'seller',
);

const _thumb = 'https://cdn.hubsom.test/live-thumb.jpg';

LiveStream _live({
  required String id,
  required String title,
  String cover = _thumb,
  int viewers = 12,
}) {
  return LiveStream(
    id: id,
    title: title,
    description: '',
    sellerId: 'seller-1',
    status: 'live',
    channelName: 'hubsom-$id',
    cover: cover,
    viewerCount: viewers,
    hosts: const [
      StreamHost(id: 'h1', name: 'Ama Host', role: 'host', avatar: ''),
    ],
  );
}

Future<void> _initStore() async {
  AppConfig.load();
  CloudStore.useNetwork = false;
  SharedPreferences.setMockInitialValues({});
  final dir = Directory.systemTemp.createTempSync('hubsom-live-thumb');
  Hive.init(dir.path);
  await LocalStore.init();
  await LocalBlobStore.init();
  await LocalStore.setUserJson(jsonEncode(_seller.toJson()));
}

Future<String> _productId() async {
  final product = await LocalCommerceStore.createProduct(
    user: _seller,
    name: 'Kente scarf',
    description: 'Handwoven',
    category: 'fashion',
    priceGhs: 120,
    stock: 4,
    images: const ['prod-a', 'prod-b', 'prod-c'],
  );
  return product.id;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('createStream cover', () {
    setUp(_initStore);

    test('refuses to go live without a thumbnail', () async {
      final productId = await _productId();
      await expectLater(
        LocalCommerceStore.createStream(
          user: _seller,
          title: 'Sunday live',
          cover: '',
          productIds: [productId],
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Add a thumbnail for Watch live and Live now'),
          ),
        ),
      );
    });

    test('stores the seller-picked thumbnail, not the product photo', () async {
      final productId = await _productId();
      final stream = await LocalCommerceStore.createStream(
        user: _seller,
        title: 'Sunday live',
        cover: _thumb,
        productIds: [productId],
        pinnedProductId: productId,
      );
      expect(stream.cover, _thumb);
      expect(stream.cover.contains('prod-'), isFalse);
      expect(LocalCommerceStore.getStream(stream.id)?.cover, _thumb);
    });

    test('persists a data-URL thumbnail as a blob ref', () async {
      final productId = await _productId();
      final dataUrl = 'data:image/jpeg;base64,${'A' * 80}';
      final stream = await LocalCommerceStore.createStream(
        user: _seller,
        title: 'Blob thumb',
        cover: dataUrl,
        productIds: [productId],
      );
      expect(LocalBlobStore.isRef(stream.cover), isTrue);
      expect(StorageMedia.isInlineData(stream.cover), isFalse);
      expect(
        LocalStore.getString('localStreams')!.contains('data:image'),
        isFalse,
      );
    });

    test('repository requires cover before creating the show', () async {
      await expectLater(
        LiveRepository(ApiClient()).createStream({
          'title': 'No thumb',
          'productIds': ['p1'],
        }),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Add a thumbnail for Watch live and Live now'),
          ),
        ),
      );
    });
  });

  testWidgets('Go live asks for a thumbnail before starting', (tester) async {
    await tester.runAsync(_initStore);
    await tester.runAsync(_productId);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SellerGoLivePage()),
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 40));
    });
    await tester.pump();
    await tester.pump();

    expect(find.text('Show thumbnail'), findsOneWidget);
    expect(find.text('Choose thumbnail'), findsOneWidget);
    expect(find.byKey(const Key('live-thumbnail-picker')), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Stream title'), 'Sunday');
    await tester.tap(find.text('Start live stream'));
    await tester.pump();

    expect(
      find.text('Add a thumbnail for Watch live and Live now'),
      findsOneWidget,
    );
  });

  testWidgets('Watch live tiles show the seller thumbnail', (tester) async {
    AppConfig.load();
    CloudStore.useNetwork = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          streamsProvider.overrideWith(
            (ref) async => [
              _live(id: 'live-1', title: 'Sunday bargains', cover: _thumb),
            ],
          ),
        ],
        child: const MaterialApp(home: LiveListPage()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Sunday bargains'), findsOneWidget);
    expect(find.text('12 watching'), findsOneWidget);
    expect(find.text('LIVE'), findsWidgets);
    final images = tester.widgetList<HubsomImage>(find.byType(HubsomImage));
    expect(images.any((w) => w.url == _thumb), isTrue);
  });

  testWidgets('Live now cards show the seller thumbnail', (tester) async {
    AppConfig.load();
    CloudStore.useNetwork = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          streamsProvider.overrideWith(
            (ref) async => [
              _live(id: 'live-1', title: 'Night market', cover: _thumb),
            ],
          ),
          productsProvider.overrideWith((ref, args) async => const []),
          promotionsProvider.overrideWith((ref, placement) async => const []),
          shopVideosProvider.overrideWith((ref) async => const []),
          sellersProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: Scaffold(body: HomePage())),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Live now'), findsOneWidget);
    expect(find.text('Night market'), findsOneWidget);
    final images = tester.widgetList<HubsomImage>(find.byType(HubsomImage));
    expect(images.any((w) => w.url == _thumb), isTrue);
  });
}
