import 'package:flutter_test/flutter_test.dart';

import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/utils/money.dart';
import 'package:hubsom_app/models/product.dart';

void main() {
  test('AppConfig loads defaults', () {
    AppConfig.load();
    expect(AppConfig.apiBaseUrl, isNotEmpty);
    expect(AppConfig.firebaseEnabled, isTrue);
  });

  test('Product effective price applies flash sale', () {
    final p = Product(
      id: '1',
      slug: 'demo',
      name: 'Demo',
      description: '',
      category: 'fashion',
      priceGhs: 100,
      images: const [],
      sellerId: 's1',
      stock: 1,
      flashSale: const FlashSale(endsAt: '2099-01-01', discountPct: 20),
    );
    expect(p.effectivePrice, 80);
    expect(formatGhs(80), contains('80'));
  });

  test('Product effective price ignores an expired flash sale', () {
    final p = Product(
      id: '2',
      slug: 'expired-sale',
      name: 'Expired',
      description: '',
      category: 'fashion',
      priceGhs: 100,
      images: const [],
      sellerId: 's1',
      stock: 1,
      flashSale: const FlashSale(endsAt: '2020-01-01T00:00:00.000Z', discountPct: 50),
    );
    expect(p.isFlashSaleActive, isFalse);
    expect(p.effectivePrice, 100);
  });
}
