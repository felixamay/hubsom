import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/core/services/local_blob_store.dart';
import 'package:hubsom_app/core/services/local_commerce_store.dart';
import 'package:hubsom_app/core/services/local_store.dart';
import 'package:hubsom_app/core/services/storage_media.dart';
import 'package:hubsom_app/models/stream.dart';
import 'package:hubsom_app/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HubsomUser seller;

  setUp(() async {
    AppConfig.load();
    CloudStore.useNetwork = false;
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('hubsom-live-quota');
    Hive.init(dir.path);
    await LocalStore.init();
    await LocalBlobStore.init();
    LocalStore.quotaMigrator = StorageMedia.migratePrefsBlobs;
    seller = const HubsomUser(
      id: 'seller-1',
      email: 'seller@hubsom.test',
      name: 'Ama Host',
      role: 'seller',
      image: 'data:image/jpeg;base64,aaaaaaaa',
    );
    await LocalStore.setUserJson(jsonEncode(seller.toJson()));
  });

  test('persistable drops inline photos and keeps http covers', () {
    expect(StorageMedia.isInlineData('data:image/jpeg;base64,abc'), isTrue);
    expect(StorageMedia.persistable('data:image/jpeg;base64,abc'), isEmpty);
    expect(
      StorageMedia.persistable('https://cdn.hubsom.com/cover.jpg'),
      'https://cdn.hubsom.com/cover.jpg',
    );
  });

  test('go live does not copy product data-URL photos onto the stream', () async {
    final blob = 'data:image/jpeg;base64,${'A' * 8000}';
    final product = await LocalCommerceStore.createProduct(
      user: seller,
      name: 'free',
      description: 'Listed',
      category: 'fashion',
      priceGhs: 200,
      stock: 3,
      images: [blob, '${blob}b', '${blob}c'],
    );
    final stream = await LocalCommerceStore.createStream(
      user: seller,
      title: 'Sunday live',
      productIds: [product.id],
      pinnedProductId: product.id,
      auctionProductId: product.id,
    );
    expect(StorageMedia.isInlineData(stream.cover), isFalse);
    expect(stream.cover.contains('data:image'), isFalse);
    expect(StorageMedia.isInlineData(stream.hosts.first.avatar), isFalse);

    final raw = LocalStore.getString('localStreams')!;
    expect(raw.contains('data:image'), isFalse);
    expect(LocalCommerceStore.getStream(stream.id)?.id, stream.id);
  });

  test('ended lives are pruned and bulky covers stripped on save', () async {
    final blob = 'data:image/jpeg;base64,${'B' * 4000}';
    for (var i = 0; i < 14; i++) {
      await LocalCommerceStore.upsertStream(
        LiveStream(
          id: 'old-$i',
          title: 'Old $i',
          description: '',
          sellerId: 'seller-1',
          status: 'ended',
          channelName: 'hubsom-old-$i',
          cover: blob,
          startedAt: '2026-09-0${(i % 9) + 1}T12:00:00Z',
          endedAt: '2026-09-0${(i % 9) + 1}T13:00:00Z',
          hosts: const [
            StreamHost(
              id: 'seller-1',
              name: 'Ama',
              role: 'host',
              avatar: 'data:image/jpeg;base64,xyz',
            ),
          ],
        ),
      );
    }
    final listed = LocalCommerceStore.listStreams();
    expect(listed.where((s) => !s.isLive).length, lessThanOrEqualTo(8));
    expect(listed.every((s) => !StorageMedia.isInlineData(s.cover)), isTrue);
    expect(
      listed.every(
        (s) => s.hosts.every((h) => !StorageMedia.isInlineData(h.avatar)),
      ),
      isTrue,
    );
  });

  test('product photos leave localStorage and still resolve', () async {
    final blob = 'data:image/jpeg;base64,${'C' * 6000}';
    final product = await LocalCommerceStore.createProduct(
      user: seller,
      name: 'free',
      description: 'Listed',
      category: 'fashion',
      priceGhs: 200,
      stock: 3,
      images: [blob, '${blob}x', '${blob}y'],
    );
    expect(product.images.every(LocalBlobStore.isRef), isTrue);
    expect(LocalStore.getString('localProducts')!.contains('data:image'), isFalse);
    expect(
      LocalBlobStore.resolve(product.images.first)?.startsWith('data:image'),
      isTrue,
    );

    final stream = await LocalCommerceStore.createStream(
      user: seller,
      title: 'Night live',
      productIds: [product.id],
      pinnedProductId: product.id,
    );
    expect(LocalStore.getString('localStreams')!.contains('data:image'), isFalse);
    expect(LocalCommerceStore.getStream(stream.id)?.isLive, isTrue);
  });

  test('startup migrate moves leftover data-URL photos into Hive', () async {
    final blob = 'data:image/jpeg;base64,${'D' * 5000}';
    await LocalStore.setString(
      'localProducts',
      jsonEncode([
        {
          'id': 'prod-old',
          'slug': 'old',
          'name': 'Old listing',
          'description': '',
          'category': 'home',
          'priceGhs': 10,
          'images': [blob, blob, blob],
          'sellerId': 'seller-1',
          'stock': 1,
        },
      ]),
      reclaim: false,
      offload: false,
    );
    // Bypass offload to simulate a device that already stored data-URLs.
    expect(LocalStore.getString('localProducts')!.contains('data:image'), isTrue);
    final moved = await StorageMedia.migratePrefsBlobs();
    expect(moved, greaterThan(0));
    expect(LocalStore.getString('localProducts')!.contains('data:image'), isFalse);
    expect(LocalStore.getString('localProducts')!.contains('hubsom-blob://'), isTrue);
  });
}
