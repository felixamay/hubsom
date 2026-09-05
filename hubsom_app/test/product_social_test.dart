import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/repositories/catalog_repository.dart';
import 'package:hubsom_app/core/services/api_client.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/core/services/local_commerce_store.dart';
import 'package:hubsom_app/core/services/local_store.dart';
import 'package:hubsom_app/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HubsomUser buyer;
  late HubsomUser seller;

  setUp(() async {
    AppConfig.load();
    CloudStore.useNetwork = false;
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('hubsom-product-social');
    Hive.init(dir.path);
    await LocalStore.init();

    seller = const HubsomUser(
      id: 'seller-1',
      email: 'seller@hubsom.test',
      name: 'Ama Seller',
      role: 'seller',
    );
    buyer = const HubsomUser(
      id: 'buyer-1',
      email: 'buyer@hubsom.test',
      name: 'Kojo Buyer',
      role: 'buyer',
    );
    await LocalStore.setUserJson(jsonEncode(seller.toJson()));
  });

  test('save like comment and timeline work for listed products', () async {
    final product = await LocalCommerceStore.createProduct(
      user: seller,
      name: 'Ankara dress',
      description: 'Listed without live',
      category: 'fashion',
      priceGhs: 180,
      stock: 4,
      images: const ['a', 'b', 'c'],
      hasDemoVideo: true,
    );

    await LocalStore.setUserJson(jsonEncode(buyer.toJson()));
    final catalog = CatalogRepository(ApiClient());

    expect(catalog.isSaved(product.id), isFalse);
    expect(await catalog.toggleSave(product.id), isTrue);
    expect(catalog.isSaved(product.id), isTrue);

    expect(catalog.isLiked(product.id), isFalse);
    expect(await catalog.toggleLike(product.id), isTrue);
    expect(catalog.likeCount(product.id), 1);
    expect(catalog.isLiked(product.id), isTrue);

    final comment = await catalog.addComment(product.id, 'Looks great!');
    expect(comment.text, 'Looks great!');
    expect((await catalog.listComments(product.id)), isNotEmpty);

    final post = await catalog.shareToTimeline(
      product.id,
      caption: 'Sunday find',
    );
    expect(post.productId, product.id);
    expect(post.caption, 'Sunday find');
    final timeline = await catalog.listTimeline();
    expect(timeline.any((p) => p.id == post.id), isTrue);
  });

  test('live share icon can post the show to timeline', () async {
    final product = await LocalCommerceStore.createProduct(
      user: seller,
      name: 'Kente wrap',
      description: 'Live lot',
      category: 'fashion',
      priceGhs: 90,
      stock: 2,
      images: const ['a', 'b', 'c'],
    );
    final stream = await LocalCommerceStore.createStream(
      user: seller,
      title: 'Saturday live',
      productIds: [product.id],
      pinnedProductId: product.id,
    );
    await LocalStore.setUserJson(jsonEncode(buyer.toJson()));
    final catalog = CatalogRepository(ApiClient());
    final post = await catalog.shareLiveToTimeline(stream.id);
    expect(post.isLivePost, isTrue);
    expect(post.streamId, stream.id);
    expect(post.type, 'live');
    expect(post.productId, product.id);
    final timeline = await catalog.listTimeline();
    expect(timeline.any((p) => p.id == post.id && p.isLivePost), isTrue);
  });
}
