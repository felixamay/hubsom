import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/providers/core_providers.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/core/services/cloud_video_media.dart';
import 'package:hubsom_app/core/services/shop_video_merge.dart';
import 'package:hubsom_app/core/services/shop_video_poster_url.dart';
import 'package:hubsom_app/features/home/home_page.dart';
import 'package:hubsom_app/models/product.dart';
import 'package:hubsom_app/models/shop_video.dart';
import 'package:hubsom_app/widgets/hubsom_image.dart';
import 'package:hubsom_app/widgets/product_demo_video_player.dart';
import 'package:hubsom_app/widgets/shop_video_poster.dart';

ShopVideo _clip({String? thumbnailUrl}) => ShopVideo(
      id: 'vid-slow',
      authorId: 'u1',
      authorName: 'Ama Seller',
      authorImage: 'https://cdn.hubsom.test/ama.png',
      caption: 'Slow-network clip',
      productIds: const ['p1'],
      videoUrl: 'https://cdn.hubsom.test/clip.mp4',
      thumbnailUrl: thumbnailUrl,
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

  test('old firestore chunk docs still assemble when ids are not sequential',
      () {
    final a = utf8.encode('HELLO-');
    final b = utf8.encode('WORLD');
    final out = CloudVideoMedia.assembleChunkDocs('vid-old', [
      {
        'id': 'legacy-chunk-b',
        'videoId': 'vid-old',
        'index': 1,
        'data': base64Encode(b),
      },
      {
        'id': 'legacy-chunk-a',
        'videoId': 'vid-old',
        'index': 0,
        'data': base64Encode(a),
      },
      {
        'id': 'other_0',
        'videoId': 'someone-else',
        'index': 0,
        'data': base64Encode(utf8.encode('NOPE')),
      },
    ]);
    expect(out, isNotNull);
    expect(utf8.decode(out!), 'HELLO-WORLD');
  });

  test('cloud hydrate keeps a local video thumbnail on Home cards', () {
    final merged = mergeShopVideoDocs(
      local: [
        {
          'id': 'vid-1',
          'authorId': 'u1',
          'authorName': 'Ama',
          'createdAt': '2026-09-06T00:00:00Z',
          'thumbnailUrl': 'https://cdn.hubsom.test/clip-thumb.jpg',
          'videoUrl': 'https://cdn.hubsom.test/clip.mp4',
        },
      ],
      incoming: [
        {
          'id': 'vid-1',
          'authorId': 'u1',
          'authorName': 'Ama',
          'createdAt': '2026-09-06T00:00:00Z',
          'videoUrl': 'https://cdn.hubsom.test/clip.mp4',
        },
      ],
    );
    expect(merged, hasLength(1));
    expect(merged.first['thumbnailUrl'], 'https://cdn.hubsom.test/clip-thumb.jpg');
  });

  test('cloud hydrate keeps https thumbnail over device blob refs', () {
    final merged = mergeShopVideoDocs(
      local: [
        {
          'id': 'vid-1',
          'authorId': 'u1',
          'authorName': 'Ama',
          'createdAt': '2026-09-06T00:00:00Z',
          'thumbnailUrl': 'https://cdn.hubsom.test/clip-thumb.jpg',
          'videoUrl': 'https://cdn.hubsom.test/clip.mp4',
        },
      ],
      incoming: [
        {
          'id': 'vid-1',
          'authorId': 'u1',
          'authorName': 'Ama',
          'createdAt': '2026-09-06T00:00:00Z',
          'thumbnailUrl': 'hubsom-blob://deadbeef',
          'videoUrl': 'https://cdn.hubsom.test/clip.mp4',
        },
      ],
    );
    expect(merged.first['thumbnailUrl'], 'https://cdn.hubsom.test/clip-thumb.jpg');
  });

  test('published shop videos without metadata use the storage still on Home',
      () {
    final clip = _clip(thumbnailUrl: null);
    final poster = ShopVideoPosterUrl.resolve(clip);
    expect(
      poster,
      contains('shopVideos%2Fvid-slow_thumb.jpg'),
    );
  });

  test('shop video json keeps a video-frame thumbnail, not a product photo', () {
    final parsed = ShopVideo.fromJson({
      'id': 'v1',
      'authorId': 'u1',
      'authorName': 'Ama',
      'createdAt': '2026-09-06T00:00:00Z',
      'videoUrl': 'https://cdn.hubsom.test/clip.mp4',
      'thumbnailUrl': 'https://cdn.hubsom.test/clip-thumb.jpg',
    });
    expect(parsed.videoPosterUrl, 'https://cdn.hubsom.test/clip-thumb.jpg');
    expect(parsed.toJson()['thumbnailUrl'], parsed.thumbnailUrl);
  });

  testWidgets('home shop video cards show a video frame, not the product photo',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          streamsProvider.overrideWith((ref) async => const []),
          productsProvider.overrideWith((ref, args) async => [_product()]),
          promotionsProvider.overrideWith((ref, placement) async => const []),
          shopVideosProvider.overrideWith(
            (ref) async => [
              _clip(thumbnailUrl: 'https://cdn.hubsom.test/clip-thumb.jpg'),
            ],
          ),
          sellersProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: Scaffold(body: HomePage())),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Slow-network clip'), findsOneWidget);
    expect(find.byType(ProductDemoVideoPlayer), findsNothing);
    expect(find.byType(ShopVideoPoster), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_fill), findsWidgets);

    final card = find.ancestor(
      of: find.text('Slow-network clip'),
      matching: find.byType(InkWell),
    );
    final thumbs = tester
        .widgetList<HubsomImage>(
          find.descendant(of: card, matching: find.byType(HubsomImage)),
        )
        .map((w) => w.url)
        .toList();
    expect(thumbs, contains('https://cdn.hubsom.test/clip-thumb.jpg'));
    expect(thumbs, isNot(contains('https://cdn.hubsom.test/bag.jpg')));
    expect(thumbs, isNot(contains('https://cdn.hubsom.test/ama.png')));
    expect(
      find.ancestor(
        of: find.byType(ShopVideoPoster),
        matching: find.byWidgetPredicate(
          (w) => w is ListView && w.scrollDirection == Axis.horizontal,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('home shop video cards fall back to storage still when metadata is empty',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          streamsProvider.overrideWith((ref) async => const []),
          productsProvider.overrideWith((ref, args) async => [_product()]),
          promotionsProvider.overrideWith((ref, placement) async => const []),
          shopVideosProvider.overrideWith(
            (ref) async => [_clip(thumbnailUrl: null)],
          ),
          sellersProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: Scaffold(body: HomePage())),
      ),
    );
    await tester.pump();
    await tester.pump();

    final card = find.ancestor(
      of: find.text('Slow-network clip'),
      matching: find.byType(InkWell),
    );
    final thumbs = tester
        .widgetList<HubsomImage>(
          find.descendant(of: card, matching: find.byType(HubsomImage)),
        )
        .map((w) => w.url)
        .toList();
    expect(
      thumbs.single,
      contains('shopVideos%2Fvid-slow_thumb.jpg'),
    );
  });
}
