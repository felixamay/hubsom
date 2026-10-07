import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/services/admin_account_store.dart';
import 'package:hubsom_app/core/services/admin_treasury_store.dart';
import 'package:hubsom_app/core/services/api_client.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/core/services/local_commerce_store.dart';
import 'package:hubsom_app/core/services/local_huber_store.dart';
import 'package:hubsom_app/core/services/local_store.dart';
import 'package:hubsom_app/core/services/payment_account_store.dart';
import 'package:hubsom_app/core/services/payment_service.dart';
import 'package:hubsom_app/models/order.dart';
import 'package:hubsom_app/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

ApiClient _offlineApi() => ApiClient(
      dio: Dio(
        BaseOptions(
          baseUrl: 'http://127.0.0.1:1',
          connectTimeout: const Duration(milliseconds: 1),
          receiveTimeout: const Duration(milliseconds: 1),
        ),
      ),
    );

const _seller = HubsomUser(
  id: 'seller-cancel',
  email: 'seller-cancel@hubsom.test',
  name: 'Ama Host',
  role: 'seller',
);

const _buyer = HubsomUser(
  id: 'buyer-cancel',
  email: 'buyer-cancel@hubsom.test',
  name: 'Kojo Buyer',
  role: 'buyer',
  walletBalanceGhs: 80,
);

const _shipping = {
  'recipientName': 'Kojo Buyer',
  'phone': '0240000000',
  'line1': 'East Legon',
  'city': 'Accra',
  'region': 'Greater Accra',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PaymentService payments;

  setUp(() async {
    AppConfig.load();
    CloudStore.useNetwork = false;
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('hubsom-order-cancel');
    Hive.init(dir.path);
    await LocalStore.init();
    await LocalCommerceStore.clearDemoAndCommerce();
    await LocalStore.remove('localOrders');
    await LocalStore.remove('localShipments');
    await LocalStore.setString(AdminTreasuryStore.payoutsKey, null);
    await LocalStore.setString(AdminTreasuryStore.intakesKey, null);
    await LocalStore.setString('paymentAccounts', null);
    await LocalStore.saveCredentialVault({
      _seller.email: {
        'email': _seller.email,
        'userJson': _seller.toJson(),
      },
      _buyer.email: {
        'email': _buyer.email,
        'userJson': _buyer.toJson(),
      },
    });
    await LocalStore.setUserJson(jsonEncode(_buyer.toJson()));
    await PaymentAccountStore.withdrawAccountFor(_buyer);
    payments = PaymentService(_offlineApi());
  });

  Future<String> listOne({int stock = 1}) async {
    final product = await LocalCommerceStore.createProduct(
      user: _seller,
      name: 'Shea butter',
      description: 'Raw',
      category: 'beauty',
      priceGhs: 40,
      stock: stock,
      images: const ['img1', 'img2', 'img3'],
    );
    return product.id;
  }

  Map<String, dynamic> shopLine(String productId) => {
        'productId': productId,
        'quantity': 1,
        'name': 'Shea butter',
        'priceGhs': 40,
        'sellerId': LocalCommerceStore.getProduct(productId)?.sellerId,
      };

  test('cancelling a paid order restocks, voids the payout, and refunds wallet',
      () async {
    final productId = await listOne();

    final paid = await payments.checkout(
      items: [shopLine(productId)],
      shipping: _shipping,
      paymentMethods: const ['wallet'],
    );
    expect(paid['ok'], isTrue);
    expect(LocalCommerceStore.availableCatalogQty(productId), 0);
    expect(AdminTreasuryStore.cachedPayouts(), hasLength(1));
    expect(PaymentAccountStore.cachedForUser(_buyer)!.balanceGhs, 40);

    final order = LocalHuberStore.listOrders().single;
    final cancelled = await LocalHuberStore.updateOrderStatus(
      order.id,
      'cancelled',
    );
    expect(cancelled.status, 'cancelled');
    expect(LocalCommerceStore.availableCatalogQty(productId), 1);
    expect(
      AdminTreasuryStore.cachedPayouts().where((p) => p.isPending),
      isEmpty,
    );
    expect(
      AdminTreasuryStore.cachedPayouts().where((p) => p.isCancelled),
      hasLength(1),
    );
    expect(AdminTreasuryStore.snapshot().collectedGhs, 0);
    expect(AdminTreasuryStore.snapshot().pendingPayoutsGhs, 0);
    expect(PaymentAccountStore.adminCached().balanceGhs, 0);
    expect(PaymentAccountStore.cachedForUser(_buyer)!.balanceGhs, 80);
    expect(
      AdminAccountStore.cached()
          .firstWhere((a) => a.email == _buyer.email)
          .user
          .walletBalanceGhs,
      80,
    );

    final again = await payments.checkout(
      items: [shopLine(productId)],
      shipping: _shipping,
      paymentMethods: const ['mtn-momo'],
    );
    expect(again['ok'], isTrue);
    expect(
      LocalHuberStore.listOrders().where((o) => o.status == 'paid'),
      hasLength(1),
    );
  });

  test('a shipped or consolidated order cannot be cancelled', () async {
    final productId = await listOne();
    await payments.checkout(
      items: [shopLine(productId)],
      shipping: _shipping,
      paymentMethods: const ['mtn-momo'],
    );
    final order = LocalHuberStore.listOrders().single;
    await LocalHuberStore.createShipmentFromOrders(
      orderIds: [order.id],
      sellerId: LocalCommerceStore.getProduct(productId)!.sellerId,
      createdByUserId: _seller.id,
      offeredFeeGhs: 15,
    );

    await expectLater(
      LocalHuberStore.updateOrderStatus(order.id, 'cancelled'),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('already on a shipment'),
        ),
      ),
    );
    expect(LocalHuberStore.getOrder(order.id)?.status, 'processing');
    expect(AdminTreasuryStore.cachedPayouts(), hasLength(1));

    await LocalHuberStore.updateOrderStatus(order.id, 'shipped');
    await LocalStore.setString('localShipments', '[]');
    await expectLater(
      LocalHuberStore.updateOrderStatus(order.id, 'cancelled'),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('shipped'),
        ),
      ),
    );
  });

  test('a paid-out sale cannot be cancelled', () async {
    final productId = await listOne();
    await payments.checkout(
      items: [shopLine(productId)],
      shipping: _shipping,
      paymentMethods: const ['mtn-momo'],
    );
    final order = LocalHuberStore.listOrders().single;
    await AdminAccountStore.save(_seller);
    await AdminTreasuryStore.paySeller(
      AdminTreasuryStore.cachedPayouts().single.id,
    );

    await expectLater(
      LocalHuberStore.updateOrderStatus(order.id, 'cancelled'),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('already paid out'),
        ),
      ),
    );
    expect(LocalHuberStore.getOrder(order.id)?.status, 'paid');
    expect(LocalCommerceStore.availableCatalogQty(productId), 0);
  });

  test('stale cloud hydrate cannot restore a cancelled payout for Pay', () async {
    final productId = await listOne();
    await payments.checkout(
      items: [shopLine(productId)],
      shipping: _shipping,
      paymentMethods: const ['mtn-momo'],
    );
    final order = LocalHuberStore.listOrders().single;
    final pending = AdminTreasuryStore.cachedPayouts().single;
    expect(pending.isPending, isTrue);

    await LocalHuberStore.updateOrderStatus(order.id, 'cancelled');
    expect(AdminTreasuryStore.cachedPayouts().single.isCancelled, isTrue);

    final mergedPayouts = CloudStore.mergePayoutDocs(
      localKey: AdminTreasuryStore.payoutsKey,
      incoming: [pending.toJson()],
    );
    await LocalStore.setString(
      AdminTreasuryStore.payoutsKey,
      jsonEncode(mergedPayouts),
    );
    final mergedIntakes = CloudStore.mergeIntakeDocs(
      localKey: AdminTreasuryStore.intakesKey,
      incoming: [
        {
          'id': 'tin_order_${order.id}',
          'source': 'order',
          'refId': order.id,
          'amountGhs': 40,
          'createdAt': '2026-10-07T11:00:00.000Z',
        },
      ],
    );
    await LocalStore.setString(
      AdminTreasuryStore.intakesKey,
      jsonEncode(mergedIntakes),
    );

    expect(AdminTreasuryStore.cachedPayouts().single.isCancelled, isTrue);
    expect(AdminTreasuryStore.snapshot().pendingPayoutsGhs, 0);
    expect(AdminTreasuryStore.snapshot().collectedGhs, 0);
    await expectLater(
      AdminTreasuryStore.paySeller(pending.id),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('cancelled'),
        ),
      ),
    );
    expect(PaymentAccountStore.cachedForUser(_seller)?.balanceGhs ?? 0, 0);

    await LocalStore.setString(AdminTreasuryStore.payoutsKey, '[]');
    final restored = CloudStore.mergePayoutDocs(
      localKey: AdminTreasuryStore.payoutsKey,
      incoming: [pending.toJson()],
    );
    expect(restored, isEmpty);
  });
}
