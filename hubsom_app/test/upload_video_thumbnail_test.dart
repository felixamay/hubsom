import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/providers/core_providers.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/features/videos/upload_video_page.dart';
import 'package:hubsom_app/models/product.dart';

void main() {
  setUp(() {
    AppConfig.load();
    CloudStore.useNetwork = false;
  });

  testWidgets('Add video has a field to upload a thumbnail', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productsProvider.overrideWith(
            (ref, args) async => [
              const Product(
                id: 'p1',
                slug: 'mug',
                sellerId: 's1',
                name: 'Video mug',
                description: '',
                category: 'home',
                priceGhs: 25,
                stock: 4,
                images: ['https://cdn.hubsom.test/mug.jpg'],
              ),
            ],
          ),
        ],
        child: const MaterialApp(home: UploadVideoPage()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Add video'), findsOneWidget);
    expect(find.text('Thumbnail'), findsOneWidget);
    expect(find.text('Upload thumbnail'), findsOneWidget);
    expect(find.text('Pick video (≤2 min, MP4)'), findsOneWidget);
    expect(find.text('Publish video'), findsOneWidget);
    expect(find.text('Publishing video…'), findsNothing);
    expect(
      find.textContaining('grab one automatically'),
      findsOneWidget,
    );
  });
}
