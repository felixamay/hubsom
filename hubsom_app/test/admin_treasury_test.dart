import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/constants/hubsom_commission.dart';
import 'package:hubsom_app/core/services/admin_account_store.dart';
import 'package:hubsom_app/core/services/admin_treasury_store.dart';
import 'package:hubsom_app/core/services/api_client.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/core/services/gift_store.dart';
import 'package:hubsom_app/core/services/local_huber_store.dart';
import 'package:hubsom_app/core/services/local_store.dart';
import 'package:hubsom_app/core/services/payment_service.dart';
import 'package:hubsom_app/models/live_gift.dart';
import 'package:hubsom_app/models/order.dart';
import 'package:hubsom_app/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _seller = HubsomUser(
  id: 'u-seller',
  email: 'seller@hubsom.test',
  name: 'Kojo Store',
  role: 'seller',
  sellerId: 's1',
);

const _buyer = HubsomUser(
  id: 'u-buyer',
  email: 'buyer@hubsom.test',
  name: 'Ama Buyer',
  role: 'buyer',
  walletBalanceGhs: 40,
);

Order _paidOrder({
  String id = 'ord_sale1',
  String status = 'paid',
  double sales = 100,
  double ship = 12,
}) {
  return Order(
    id: id,
    subtotalGhs: sales + ship,
    shipmentFeeGhs: ship,
    status: status,
    userId: _buyer.id,
    buyerName: _buyer.name,
    buyerEmail: _buyer.email,
    lines: [
      OrderLine(
        productId: 'p1',
        sellerId: 's1',
        name: 'Shea butter',
        quantity: 1,
        unitPriceGhs: sales,
        lineTotalGhs: sales,
        category: 'beauty',
        shipmentFeeGhs: ship,
      ),
    ],
    paymentMethods: const ['mtn-momo'],
    createdAt: '2026-09-06T00:00:00.000Z',
  );
}

Future<void> _init() async {
  AppConfig.load();
  CloudStore.useNetwork = false;
  SharedPreferences.setMockInitialValues({});
  Hive.init(Directory.systemTemp.createTempSync('hubsom-treasury').path);
  await LocalStore.init();
  await LocalStore.setString(AdminTreasuryStore.payoutsKey, null);
  await LocalStore.setString(AdminTreasuryStore.intakesKey, null);
  await LocalStore.setString('paymentAccounts', null);
  await LocalStore.setString('localOrders', null);
  await LocalStore.saveCredentialVault({
    _seller.email: {
      'email': _seller.email,
      'name': _seller.name,
      'role': _seller.role,
      'userJson': _seller.toJson(),
    },
    _buyer.email: {
      'email': _buyer.email,
      'userJson': _buyer.toJson(),
    },
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(_init);

  test('Hubsom keeps 6 percent and sellers net 94 percent', () {
    expect(HubsomCommission.commissionOn(100), 6);
    expect(HubsomCommission.netOn(100), 94);
    expect(HubsomCommission.commissionOn(10.01) + HubsomCommission.netOn(10.01),
        closeTo(10.01, 0.001));
  });

  test('paid orders settle to admin and wait for a 94 percent payout', () async {
    final order = _paidOrder();
    await LocalHuberStore.saveOrder(order);
    await AdminTreasuryStore.recordPaidOrder(order);
    await AdminTreasuryStore.recordPaidOrder(order);

    final snap = AdminTreasuryStore.snapshot();
    expect(snap.collectedGhs, 112);
    expect(snap.commissionGhs, 6);
    expect(snap.pendingPayoutsGhs, 94);
    expect(snap.shipmentHeldGhs, 12);
    expect(AdminTreasuryStore.cachedPayouts(), hasLength(1));
    expect(order.paidToAccountId, 'pay_admin');

    final paid = await AdminTreasuryStore.paySeller(
      AdminTreasuryStore.payoutId(order.id, 's1'),
    );
    expect(paid.isPaid, isTrue);
    expect(
      AdminAccountStore.cached()
          .firstWhere((a) => a.email == _seller.email)
          .user
          .walletBalanceGhs,
      94,
    );
    expect(AdminTreasuryStore.snapshot().pendingPayoutsGhs, 0);
    expect(AdminTreasuryStore.snapshot().paidOutGhs, 94);
  });

  test('cancelled orders are not collected by admin', () async {
    await AdminTreasuryStore.recordPaidOrder(_paidOrder(status: 'cancelled'));
    expect(AdminTreasuryStore.cachedPayouts(), isEmpty);
    expect(AdminTreasuryStore.snapshot().collectedGhs, 0);
  });

  test('external gift purchases go to admin; wallet packs do not', () async {
    await LocalStore.setUserJson(jsonEncode(_buyer.toJson()));

    await GiftStore.buyPoints(
      user: _buyer,
      pack: GiftCatalog.packById('p100')!,
      paymentMethod: 'mtn-momo',
    );
    expect(AdminTreasuryStore.cachedIntakes().single.source, 'gift');
    expect(AdminTreasuryStore.cachedIntakes().single.amountGhs, 10);

    await GiftStore.buyPoints(
      user: _buyer.copyWith(giftPoints: 100),
      pack: GiftCatalog.packById('p100')!,
      paymentMethod: 'wallet',
    );
    expect(AdminTreasuryStore.cachedIntakes(), hasLength(1));
  });

  test('syncFromOrders backfills payouts from existing paid sales', () async {
    await LocalHuberStore.saveOrder(_paidOrder(id: 'ord_old'));
    final rows = await AdminTreasuryStore.syncFromOrders();
    expect(rows, hasLength(1));
    expect(rows.single.netGhs, 94);
    expect(rows.single.sellerId, 's1');
  });

  test('checkout sends the sale through Hubsom Admin', () async {
    final res = await PaymentService(ApiClient()).checkout(
      items: [
        {
          'productId': 'p1',
          'name': 'Shea butter',
          'priceGhs': 100,
          'quantity': 1,
          'shipmentFeeGhs': 12,
          'sellerId': 's1',
        },
      ],
      shipping: {
        'recipientName': 'Ama Buyer',
        'phone': '0240000000',
        'line1': '12 Spintex Rd',
        'city': 'Accra',
        'region': 'Greater Accra',
      },
      paymentMethods: const ['mtn-momo'],
    );
    expect(res['ok'], isTrue);
    final snap = AdminTreasuryStore.snapshot();
    expect(snap.collectedGhs, 112);
    expect(snap.commissionGhs, 6);
    expect(snap.pendingPayoutsGhs, 94);
  });
}
