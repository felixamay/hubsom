import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/providers/core_providers.dart';
import 'package:hubsom_app/core/repositories/seller_repository.dart';
import 'package:hubsom_app/core/services/api_client.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/core/services/local_commerce_store.dart';
import 'package:hubsom_app/core/services/local_huber_store.dart';
import 'package:hubsom_app/core/services/local_store.dart';
import 'package:hubsom_app/core/services/payment_service.dart';
import 'package:hubsom_app/models/order.dart';
import 'package:hubsom_app/models/product.dart';
import 'package:hubsom_app/models/user.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

Uint8List _jpeg() {
  final image = img.Image(width: 64, height: 64);
  img.fill(image, color: img.ColorRgb8(40, 120, 80));
  return Uint8List.fromList(img.encodeJpg(image, quality: 80));
}

String _dataUrl() =>
    'data:image/jpeg;base64,${base64Encode(_jpeg())}';

Future<void> _init() async {
  AppConfig.load();
  CloudStore.useNetwork = false;
  SharedPreferences.setMockInitialValues({});
  final dir = Directory.systemTemp.createTempSync('hubsom-ship-fee');
  Hive.init(dir.path);
  await LocalStore.init();
  await LocalStore.setUserJson(
    jsonEncode({
      'id': 'u1',
      'email': 'seller@hubsom.test',
      'name': 'Seller',
      'role': 'seller',
    }),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(_init);

  test('create and update product persist shipment fee for store and live lots',
      () async {
    final repo = SellerRepository(ApiClient());
    final photos = [_dataUrl(), _dataUrl(), _dataUrl()];
    final store = await repo.createProduct({
      'name': 'Wax print',
      'description': 'Bright Accra wax print cloth',
      'category': 'fashion',
      'priceGhs': 120,
      'shipmentFeeGhs': 18,
      'stock': 5,
      'images': photos,
    });
    expect(store['shipmentFeeGhs'], 18);
    expect(
      LocalCommerceStore.getProduct(store['id'] as String)?.shipmentFeeGhs,
      18,
    );

    final lot = await repo.createProduct({
      'name': 'Live lot bag',
      'description': 'Auction lot for tonight live',
      'category': 'fashion',
      'priceGhs': 200,
      'shipmentFeeGhs': 25,
      'stock': 1,
      'images': photos,
      'auctionOnly': true,
    });
    expect(lot['auctionOnly'], true);
    expect(lot['shipmentFeeGhs'], 25);

    final updated = await repo.updateProduct(store['id'] as String, {
      'name': 'Wax print',
      'description': 'Bright Accra wax print cloth',
      'category': 'fashion',
      'priceGhs': 120,
      'shipmentFeeGhs': 22,
      'stock': 5,
      'images': photos,
    });
    expect(updated['shipmentFeeGhs'], 22);
    expect(
      LocalCommerceStore.getProduct(store['id'] as String)?.shipmentFeeGhs,
      22,
    );
  });

  test('cart and checkout include product shipment fee in the payable total',
      () async {
    final product = Product(
      id: 'p-ship',
      slug: 'p-ship',
      name: 'Shea butter',
      description: 'Raw shea',
      category: 'beauty',
      priceGhs: 40,
      shipmentFeeGhs: 12,
      images: const ['img'],
      sellerId: 's1',
      stock: 8,
    );
    final cart = CartController();
    await cart.clear();
    await cart.addProduct(product, quantity: 2, source: 'live');
    expect(cart.state.single.shipmentFeeGhs, 12);
    expect(cart.subtotal, 80);
    expect(cart.shipmentTotal, 24);
    expect(cart.payableTotal, 104);

    final payment = PaymentService(ApiClient());
    final res = await payment.checkout(
      items: cart.state.map((e) => e.toJson()).toList(),
      shipping: {
        'recipientName': 'Kojo Buyer',
        'phone': '0241111111',
        'line1': '12 Spintex Rd',
        'city': 'Accra',
        'region': 'Greater Accra',
      },
      paymentMethods: const ['mtn-momo'],
      streamId: 'live-1',
    );
    final order = Order.fromJson(
      Map<String, dynamic>.from(res['order'] as Map),
    );
    expect(order.shipmentFeeGhs, 24);
    expect(order.subtotalGhs, 104);
    expect(order.lines.single.shipmentFeeGhs, 12);
    expect(order.effectiveShipmentFeeGhs, 24);
  });

  test('consolidating orders prefills rider offer from product shipment fee',
      () async {
    const user = HubsomUser(
      id: 'u1',
      email: 'seller@hubsom.test',
      name: 'Seller',
      role: 'seller',
    );
    final product = await LocalCommerceStore.createProduct(
      user: user,
      name: 'Kente scarf',
      description: 'Handwoven kente scarf for live',
      category: 'fashion',
      priceGhs: 90,
      shipmentFeeGhs: 15,
      stock: 3,
      images: [_dataUrl(), _dataUrl(), _dataUrl()],
    );
    await LocalHuberStore.saveOrder(
      Order(
        id: 'ord-ship-fee',
        subtotalGhs: 105,
        shipmentFeeGhs: 15,
        status: 'paid',
        lines: [
          OrderLine(
            productId: product.id,
            sellerId: product.sellerId,
            name: product.name,
            quantity: 1,
            unitPriceGhs: 90,
            lineTotalGhs: 90,
            category: 'fashion',
            shipmentFeeGhs: 15,
          ),
        ],
        shipping: const OrderShipping(
          recipientName: 'Kojo Buyer',
          phone: '0241111111',
          line1: 'East Legon',
          city: 'Accra',
          region: 'Greater Accra',
        ),
        createdAt: DateTime.now().toUtc().toIso8601String(),
      ),
    );

    final shipment = await LocalHuberStore.createShipmentFromOrders(
      orderIds: const ['ord-ship-fee'],
      sellerId: product.sellerId,
      createdByUserId: user.id,
    );
    expect(shipment.offeredFeeGhs, 15);
  });
}
