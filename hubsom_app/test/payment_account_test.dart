import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/constants/hubsom_commission.dart';
import 'package:hubsom_app/core/services/admin_account_store.dart';
import 'package:hubsom_app/core/services/admin_treasury_store.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/core/services/local_store.dart';
import 'package:hubsom_app/core/services/gift_store.dart';
import 'package:hubsom_app/core/services/payment_account_store.dart';
import 'package:hubsom_app/core/services/withdrawal_store.dart';
import 'package:hubsom_app/models/live_gift.dart';
import 'package:hubsom_app/models/order.dart';
import 'package:hubsom_app/models/payment_account.dart';
import 'package:hubsom_app/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _seller = HubsomUser(
  id: 'u-seller',
  email: 'seller@hubsom.test',
  name: 'Kojo Store',
  role: 'seller',
  sellerId: 's1',
);

Order _sale() => Order(
      id: 'ord_pay1',
      subtotalGhs: 112,
      shipmentFeeGhs: 12,
      status: 'paid',
      userId: 'u-buyer',
      lines: const [
        OrderLine(
          productId: 'p1',
          sellerId: 's1',
          name: 'Shea butter',
          quantity: 1,
          unitPriceGhs: 100,
          lineTotalGhs: 100,
          category: 'beauty',
          shipmentFeeGhs: 12,
        ),
      ],
      paymentMethods: const ['mtn-momo'],
      paidToAccountId: PaymentAccount.adminId,
      createdAt: '2026-09-06T00:00:00.000Z',
    );

Future<void> _init() async {
  AppConfig.load();
  CloudStore.useNetwork = false;
  SharedPreferences.setMockInitialValues({});
  Hive.init(Directory.systemTemp.createTempSync('hubsom-pay-accounts').path);
  await LocalStore.init();
  await LocalStore.setString(AdminTreasuryStore.payoutsKey, null);
  await LocalStore.setString(AdminTreasuryStore.intakesKey, null);
  await LocalStore.setString('paymentAccounts', null);
  await LocalStore.setString('adminAccountsCache', null);
  await LocalStore.setString(WithdrawalStore.key, null);
  await LocalStore.saveCredentialVault({
    _seller.email: {
      'email': _seller.email,
      'userJson': _seller.toJson(),
    },
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(_init);

  test('admin commission is 6 percent on every product sale', () {
    expect(HubsomCommission.rate, 0.06);
    expect(HubsomCommission.commissionOn(200), 12);
    expect(HubsomCommission.netOn(200), 188);
  });

  test('product payments credit only the admin receive account', () async {
    await AdminTreasuryStore.recordPaidOrder(_sale());
    final admin = PaymentAccountStore.adminCached();
    expect(admin.canReceive, isTrue);
    expect(admin.balanceGhs, 112);
    expect(_sale().paidToAccountId, PaymentAccount.adminId);

    final sellerAccount = await PaymentAccountStore.withdrawAccountFor(_seller);
    expect(sellerAccount.canReceive, isFalse);
    expect(sellerAccount.canWithdraw, isTrue);
    expect(sellerAccount.balanceGhs, 0);
  });

  test('user and seller accounts cannot receive product payments', () async {
    await expectLater(
      PaymentAccountStore.receiveProductPayment(
        orderId: 'ord_bad',
        amountGhs: 40,
        destinationAccountId: PaymentAccount.userIdFor(_seller.id),
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('admin payment account'),
        ),
      ),
    );
  });

  test('admin payout funds a withdraw account and the user can cash out',
      () async {
    await AdminTreasuryStore.recordPaidOrder(_sale());
    await AdminTreasuryStore.paySeller(
      AdminTreasuryStore.payoutId('ord_pay1', 's1'),
    );

    final admin = PaymentAccountStore.adminCached();
    expect(admin.balanceGhs, 18);
    final sellerAccount = await PaymentAccountStore.withdrawAccountFor(
      AdminAccountStore.cached()
          .firstWhere((a) => a.email == _seller.email)
          .user,
    );
    expect(sellerAccount.balanceGhs, 94);
    expect(sellerAccount.canReceive, isFalse);

    final user = AdminAccountStore.cached()
        .firstWhere((a) => a.email == _seller.email)
        .user;
    final out = await PaymentAccountStore.withdraw(
      user: user,
      amountGhs: 40,
      rail: 'mtn-momo',
      handle: '0240000000',
    );
    expect(out.account.balanceGhs, 54);
    expect(out.user.walletBalanceGhs, 54);
    expect(out.request.isPending, isTrue);
    expect(out.request.handle, '0240000000');
    expect(out.request.amountGhs, 40);
    expect(WithdrawalStore.pending(), hasLength(1));

    final processed = await PaymentAccountStore.processWithdrawal(out.request.id);
    expect(processed.isProcessed, isTrue);
    expect(processed.processedAt, isNotEmpty);
    expect(WithdrawalStore.pending(), isEmpty);
    expect(
      PaymentAccountStore.cachedForUser(out.user)?.balanceGhs,
      54,
    );
  });

  test('withdraw needs a number and stays pending until processed', () async {
    final user = _seller.copyWith(walletBalanceGhs: 80);
    final funded = await PaymentAccountStore.withdrawAccountFor(user);
    expect(funded.balanceGhs, 80);

    await expectLater(
      PaymentAccountStore.withdraw(
        user: user,
        amountGhs: 20,
        rail: 'mtn-momo',
        handle: '',
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('MoMo number'),
        ),
      ),
    );

    final submitted = await PaymentAccountStore.withdraw(
      user: user,
      amountGhs: 20,
      rail: 'mtn-momo',
      handle: '0551234567',
    );
    expect(submitted.request.status, 'pending');
    expect(WithdrawalStore.forUser(_seller.id).single.isPending, isTrue);

    await PaymentAccountStore.processWithdrawal(submitted.request.id);
    expect(WithdrawalStore.forUser(_seller.id).single.isProcessed, isTrue);
  });

  test('gift earnings land on the payment account so the host can cash out',
      () async {
    const host = HubsomUser(
      id: 'u-host',
      email: 'host@hubsom.test',
      name: 'Ama Host',
      role: 'seller',
      sellerId: 's-host',
      giftEarningsGhs: 8,
    );
    await LocalStore.saveCredentialVault({
      host.email: {
        'email': host.email,
        'userJson': host.toJson(),
      },
    });
    await LocalStore.setUserJson(jsonEncode(host.toJson()));

    final moved = await GiftStore.withdrawEarnings(host);
    expect(moved.walletBalanceGhs, 8);
    expect(moved.giftEarningsGhs, 0);
    expect(
      PaymentAccountStore.cachedForUser(moved)?.balanceGhs,
      8,
    );

    final out = await PaymentAccountStore.withdraw(
      user: moved,
      amountGhs: 8,
      rail: 'mtn-momo',
      handle: '0241111111',
    );
    expect(out.account.balanceGhs, 0);
    expect(out.user.walletBalanceGhs, 0);
    expect(out.request.amountGhs, 8);
  });

  test('wallet gift packs debit the payment account, not only the profile',
      () async {
    await AdminTreasuryStore.recordPaidOrder(_sale());
    await AdminTreasuryStore.paySeller(
      AdminTreasuryStore.payoutId('ord_pay1', 's1'),
    );
    final seller = AdminAccountStore.cached()
        .firstWhere((a) => a.email == _seller.email)
        .user;
    expect(seller.walletBalanceGhs, 94);
    expect(
      PaymentAccountStore.cachedForUser(seller)?.balanceGhs,
      94,
    );

    await LocalStore.setUserJson(jsonEncode(seller.toJson()));
    final bought = await GiftStore.buyPoints(
      user: seller,
      pack: GiftCatalog.packById('p100')!,
      paymentMethod: 'wallet',
    );
    expect(bought.walletBalanceGhs, 84);
    expect(bought.giftPoints, 100);
    expect(
      PaymentAccountStore.cachedForUser(bought)?.balanceGhs,
      84,
    );

    await expectLater(
      PaymentAccountStore.withdraw(
        user: bought,
        amountGhs: 94,
        rail: 'mtn-momo',
        handle: '0242222222',
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Payment account needs'),
        ),
      ),
    );
  });

  test('wallet spend with the same ref does not debit twice', () async {
    final user = _seller.copyWith(walletBalanceGhs: 40);
    await PaymentAccountStore.withdrawAccountFor(user);
    await PaymentAccountStore.spendFromWithdrawAccount(
      user: user,
      amountGhs: 10,
      ref: 'ord_dup',
    );
    final again = await PaymentAccountStore.spendFromWithdrawAccount(
      user: user,
      amountGhs: 10,
      ref: 'ord_dup',
    );
    expect(again.balanceGhs, 30);
  });
}
