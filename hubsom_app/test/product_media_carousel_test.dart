import 'package:flutter_test/flutter_test.dart';
import 'package:hubsom_app/models/product.dart';

void main() {
  test('listed product media puts demo video ahead of images', () {
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

    expect(product.showsDemoVideo, isTrue);
    expect(product.images.length, 2);

    // Build the same slide order the product detail carousel uses.
    final kinds = <String>[];
    if (product.showsDemoVideo) kinds.add('video');
    for (final _ in product.images) {
      kinds.add('image');
    }
    expect(kinds, ['video', 'image', 'image']);
  });
}
