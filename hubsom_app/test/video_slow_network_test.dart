import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/providers/core_providers.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/core/services/cloud_video_media.dart';
import 'package:hubsom_app/features/home/home_page.dart';
import 'package:hubsom_app/models/product.dart';
import 'package:hubsom_app/models/shop_video.dart';
import 'package:hubsom_app/widgets/product_demo_video_player.dart';

ShopVideo _clip() => ShopVideo(
      id: 'vid-slow',
      authorId: 'u1',
      authorName: 'Ama Seller',
      authorImage: 'https://cdn.hubsom.test/ama.png',
      caption: 'Slow-network clip',
      productIds: const ['p1'],
      videoUrl: 'https://cdn.hubsom.test/clip.mp4',
      createdAt: '2026-09-06T00:00:00Z',
    );

Product _product() => const Product(
      id: 'p1',
      slug: 'wax-bag',
      sellerId: 's1',
      name: 'Wax bag',
      description: '',
      category: 'fashion',
      priceGhs: 40,
      stock: 4,
      images: ['https://cdn.hubsom.test/bag.jpg'],
    );

void main() {
  setUp(() {
    AppConfig.load();
    CloudStore.useNetwork = false;
  });

  test('https shop videos do not download the whole file into Hive first',
      () async {
    final ok = await CloudVideoMedia.ensureLocalBytes(
      videoId: 'vid-slow',
      videoUrl: 'https://cdn.hubsom.test/clip.mp4',
    );
    expect(ok, isFalse);
  });

  testWidgets('home shop video cards show a still instead of starting players',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          streamsProvider.overrideWith((ref) async => const []),
          productsProvider.overrideWith((ref, args) async => [_product()]),
          promotionsProvider.overrideWith((ref, placement) async => const []),
          shopVideosProvider.overrideWith((ref) async => [_clip()]),
          sellersProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: Scaffold(body: HomePage())),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Slow-network clip'), findsOneWidget);
    expect(find.byType(ProductDemoVideoPlayer), findsNothing);
    expect(find.byIcon(Icons.play_circle_fill), findsWidgets);
  });
}
