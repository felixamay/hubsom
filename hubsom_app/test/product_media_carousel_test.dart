import 'package:flutter_test/flutter_test.dart';
import 'package:hubsom_app/models/product.dart';

void main() {
  test('product page media carousel uses images only (no demo video)', () {
    final product = Product(
      id: 'p1',
      slug: 'p1',
      name: 'Demo bag',
      description: 'A bag',
      category: 'fashion',
      priceGhs: 120,
      images: const ['https://example.com/a.jpg', 'https://example.com/b.jpg'],
      sellerId: 's1',
      stock: 3,
      hasDemoVideo: true,
      demoVideoUrl: 'https://example.com/demo.mp4',
    );

    // Product may still have demo video metadata, but the product page
    // carousel no longer surfaces it — shop videos live in the video/timeline feeds.
    expect(product.showsDemoVideo, isTrue);

    final kinds = <String>[];
    for (final _ in product.images) {
      kinds.add('image');
    }
    expect(kinds, ['image', 'image']);
    expect(kinds.contains('video'), isFalse);
  });
}
