import 'package:flutter_test/flutter_test.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';

void main() {
  test('Firestore REST codec round-trips account records', () {
    final record = {
      'email': 'ama@hubsom.test',
      'name': 'Ama',
      'role': 'huber',
      'salt': 'abc',
      'hash': 'def123',
      'userJson': {
        'id': 'u1',
        'email': 'ama@hubsom.test',
        'name': 'Ama',
        'role': 'huber',
        'walletBalanceGhs': 12.5,
        'followingSellerIds': <String>[],
      },
    };
    final fields = CloudStore.encodeFields(record);
    final decoded = CloudStore.decodeFields(fields);
    expect(decoded['email'], 'ama@hubsom.test');
    expect(decoded['role'], 'huber');
    expect(decoded['hash'], 'def123');
    final user = Map<String, dynamic>.from(decoded['userJson'] as Map);
    expect(user['id'], 'u1');
    expect(user['walletBalanceGhs'], 12.5);
    expect(CloudStore.accountDocId('  Ama@Hubsom.TEST '), 'ama@hubsom.test');
    expect(
      CloudStore.accountDocId('ama\u200b@hubsom.test'),
      'ama@hubsom.test',
    );
  });

  test('account PATCH mask updates only the fields being written', () {
    final fields = CloudStore.encodeFields({
      'salt': 'abc',
      'hash': 'def123',
      'email': 'ama@hubsom.test',
      'userJson': {
        'id': 'u1',
        'email': 'ama@hubsom.test',
        'giftPoints': 40,
      },
      'updatedAt': '2026-09-23T11:00:00.000Z',
    });
    final query = CloudStore.accountPatchQuery(
      apiKey: 'test-key',
      fields: fields,
    );
    final mask = query['updateMask.fieldPaths'] as List;
    expect(query['key'], 'test-key');
    expect(
      mask,
      containsAll(['salt', 'hash', 'email', 'userJson', 'updatedAt']),
    );
    expect(mask, isNot(contains('passkeys')));
    expect(mask, isNot(contains('suspended')));
  });

  test('gift persist payload keeps passkeys and suspension on the record', () {
    final vault = {
      'salt': 'abc',
      'hash': 'def123',
      'email': 'ama@hubsom.test',
      'passkeys': [
        {'id': 'pk-1', 'email': 'ama@hubsom.test'},
      ],
      'suspended': true,
      'userJson': {'id': 'u1', 'email': 'ama@hubsom.test', 'giftPoints': 0},
    };
    final payload = {
      ...vault,
      'userJson': {'id': 'u1', 'email': 'ama@hubsom.test', 'giftPoints': 40},
      'email': 'ama@hubsom.test',
    };
    expect(payload['passkeys'], isNotEmpty);
    expect(payload['suspended'], isTrue);
    expect(
      Map<String, dynamic>.from(payload['userJson'] as Map)['giftPoints'],
      40,
    );
  });

  test('hydrate keeps a local spend over a stale payment-account snapshot', () {
    const id = 'pay_user_buyer';
    final spent = {
      'id': id,
      'ownerUserId': 'buyer',
      'email': 'buyer@hubsom.test',
      'name': 'Kojo',
      'kind': 'user_withdraw',
      'balanceGhs': 20,
      'creditedRefs': ['spend_ord_1'],
      'updatedAt': '2026-10-03T11:00:00.000Z',
    };
    final staleCloud = {
      'id': id,
      'ownerUserId': 'buyer',
      'email': 'buyer@hubsom.test',
      'name': 'Kojo',
      'kind': 'user_withdraw',
      'balanceGhs': 100,
      'creditedRefs': <String>[],
      'updatedAt': '2026-10-03T10:00:00.000Z',
    };
    final merged = CloudStore.mergePaymentAccountRows(
      local: [spent],
      incoming: [staleCloud],
    );
    expect(merged, hasLength(1));
    expect(merged.single['balanceGhs'], 20);
    expect(merged.single['creditedRefs'], ['spend_ord_1']);
  });

  test('hydrate keeps a local pending withdrawal a stale snapshot omitted', () {
    final pending = {
      'id': 'wd-new',
      'userId': 'seller',
      'userName': 'Ama',
      'userEmail': 'seller@hubsom.test',
      'amountGhs': 40,
      'rail': 'mtn-momo',
      'handle': '0240000000',
      'status': 'pending',
      'createdAt': '2026-10-04T11:00:00.000Z',
    };
    final older = {
      'id': 'wd-old',
      'userId': 'seller',
      'userName': 'Ama',
      'userEmail': 'seller@hubsom.test',
      'amountGhs': 10,
      'rail': 'mtn-momo',
      'handle': '0240000000',
      'status': 'processed',
      'createdAt': '2026-10-01T11:00:00.000Z',
      'processedAt': '2026-10-01T12:00:00.000Z',
    };
    final merged = CloudStore.mergeWithdrawalRows(
      local: [pending, older],
      incoming: [older],
    );
    expect(merged.map((e) => e['id']), containsAll(['wd-new', 'wd-old']));
    expect(
      merged.firstWhere((e) => e['id'] == 'wd-new')['status'],
      'pending',
    );
  });

  test('hydrate prefers a processed withdrawal over a stale pending copy', () {
    const id = 'wd-1';
    final pending = {
      'id': id,
      'userId': 'seller',
      'amountGhs': 40,
      'status': 'pending',
      'createdAt': '2026-10-04T11:00:00.000Z',
    };
    final processed = {
      'id': id,
      'userId': 'seller',
      'amountGhs': 40,
      'status': 'processed',
      'createdAt': '2026-10-04T11:00:00.000Z',
      'processedAt': '2026-10-04T12:00:00.000Z',
    };
    expect(
      CloudStore.mergeWithdrawalRows(
        local: [pending],
        incoming: [processed],
      ).single['status'],
      'processed',
    );
    expect(
      CloudStore.mergeWithdrawalRows(
        local: [processed],
        incoming: [pending],
      ).single['status'],
      'processed',
    );
  });

  test('hydrate takes a newer cloud payout over a stale local balance', () {
    const id = 'pay_user_seller';
    final local = {
      'id': id,
      'ownerUserId': 'seller',
      'email': 'seller@hubsom.test',
      'name': 'Ama',
      'kind': 'user_withdraw',
      'balanceGhs': 0,
      'creditedRefs': <String>[],
      'updatedAt': '2026-10-03T10:00:00.000Z',
    };
    final paidOut = {
      'id': id,
      'ownerUserId': 'seller',
      'email': 'seller@hubsom.test',
      'name': 'Ama',
      'kind': 'user_withdraw',
      'balanceGhs': 94,
      'creditedRefs': ['pot_ord_1_s1'],
      'updatedAt': '2026-10-03T11:00:00.000Z',
    };
    final merged = CloudStore.mergePaymentAccountRows(
      local: [local],
      incoming: [paidOut],
    );
    expect(merged.single['balanceGhs'], 94);
    expect(merged.single['creditedRefs'], ['pot_ord_1_s1']);
  });

  test('hydrate keeps a local paid order a stale snapshot omitted', () {
    final paid = {
      'id': 'ord_new',
      'subtotalGhs': 50,
      'status': 'paid',
      'userId': 'u-buyer',
      'lines': [
        {
          'productId': 'p1',
          'name': 'Shea',
          'quantity': 1,
          'unitPriceGhs': 50,
          'lineTotalGhs': 50,
          'category': 'beauty',
        },
      ],
      'paymentMethods': ['wallet'],
      'createdAt': '2026-10-05T11:00:00.000Z',
    };
    final older = {
      'id': 'ord_old',
      'subtotalGhs': 20,
      'status': 'delivered',
      'userId': 'u-buyer',
      'lines': [
        {
          'productId': 'p2',
          'name': 'Soap',
          'quantity': 1,
          'unitPriceGhs': 20,
          'lineTotalGhs': 20,
          'category': 'beauty',
        },
      ],
      'paymentMethods': ['mtn-momo'],
      'createdAt': '2026-10-01T11:00:00.000Z',
    };
    final merged = CloudStore.mergeOrderRows(
      local: [paid, older],
      incoming: [older],
    );
    expect(merged.map((e) => e['id']), containsAll(['ord_new', 'ord_old']));
    expect(
      merged.firstWhere((e) => e['id'] == 'ord_new')['status'],
      'paid',
    );
  });

  test('hydrate keeps delivered over a stale paid cloud copy', () {
    const id = 'ord_1';
    final delivered = {
      'id': id,
      'subtotalGhs': 50,
      'status': 'delivered',
      'createdAt': '2026-10-05T11:00:00.000Z',
    };
    final paid = {
      'id': id,
      'subtotalGhs': 50,
      'status': 'paid',
      'createdAt': '2026-10-05T11:00:00.000Z',
    };
    expect(
      CloudStore.mergeOrderRows(
        local: [delivered],
        incoming: [paid],
      ).single['status'],
      'delivered',
    );
    expect(
      CloudStore.mergeOrderRows(
        local: [paid],
        incoming: [delivered],
      ).single['status'],
      'delivered',
    );
  });

  test('hydrate does not resurrect a cancelled order from a stale paid copy', () {
    const id = 'ord_1';
    final cancelled = {
      'id': id,
      'subtotalGhs': 50,
      'status': 'cancelled',
      'createdAt': '2026-10-05T11:00:00.000Z',
    };
    final paid = {
      'id': id,
      'subtotalGhs': 50,
      'status': 'paid',
      'createdAt': '2026-10-05T11:00:00.000Z',
    };
    expect(
      CloudStore.mergeOrderRows(
        local: [cancelled],
        incoming: [paid],
      ).single['status'],
      'cancelled',
    );
    expect(
      CloudStore.mergeOrderRows(
        local: [paid],
        incoming: [cancelled],
      ).single['status'],
      'cancelled',
    );
  });

  test('hydrate keeps a local shipment a stale snapshot omitted', () {
    Map<String, dynamic> lot({
      required String id,
      required String status,
      String? assignedHuberId,
    }) =>
        {
          'id': id,
          'sellerId': 'seller-1',
          'createdByUserId': 'seller-1',
          'orderIds': [id.replaceFirst('shp_', 'ord_')],
          'items': const [],
          'destination': {
            'recipientName': 'Buyer',
            'phone': '0241111111',
            'line1': '12 Spintex Rd',
            'city': 'Accra',
            'region': 'Greater Accra',
          },
          'status': status,
          if (assignedHuberId != null) 'assignedHuberId': assignedHuberId,
          'createdAt': '2026-10-06T11:00:00.000Z',
          'updatedAt': '2026-10-06T11:00:00.000Z',
        };
    final fresh = lot(id: 'shp_new', status: 'ready');
    final older = lot(id: 'shp_old', status: 'delivered');
    final merged = CloudStore.mergeShipmentRows(
      local: [fresh, older],
      incoming: [older],
    );
    expect(merged.map((e) => e['id']), containsAll(['shp_new', 'shp_old']));
    expect(
      merged.firstWhere((e) => e['id'] == 'shp_new')['status'],
      'ready',
    );
  });

  test('hydrate keeps assigned over a stale offering cloud copy', () {
    const id = 'shp_1';
    Map<String, dynamic> lot(String status, {String? assignedHuberId}) => {
          'id': id,
          'sellerId': 'seller-1',
          'status': status,
          if (assignedHuberId != null) 'assignedHuberId': assignedHuberId,
        };
    expect(
      CloudStore.mergeShipmentRows(
        local: [lot('assigned', assignedHuberId: 'huber-ama')],
        incoming: [lot('offering')],
      ).single['assignedHuberId'],
      'huber-ama',
    );
    expect(
      CloudStore.mergeShipmentRows(
        local: [lot('offering')],
        incoming: [lot('assigned', assignedHuberId: 'huber-ama')],
      ).single['assignedHuberId'],
      'huber-ama',
    );
  });

  test('hydrate does not resurrect a cancelled shipment from a stale ready copy',
      () {
    const id = 'shp_1';
    final cancelled = {'id': id, 'status': 'cancelled'};
    final ready = {'id': id, 'status': 'ready'};
    expect(
      CloudStore.mergeShipmentRows(
        local: [cancelled],
        incoming: [ready],
      ).single['status'],
      'cancelled',
    );
    expect(
      CloudStore.mergeShipmentRows(
        local: [ready],
        incoming: [cancelled],
      ).single['status'],
      'cancelled',
    );
  });

  test('hydrate keeps a local payout a stale snapshot omitted', () {
    final fresh = {
      'id': 'pot_ord_new_s1',
      'sellerId': 's1',
      'orderId': 'ord_new',
      'salesGhs': 100,
      'netGhs': 94,
      'status': 'pending',
      'createdAt': '2026-10-07T11:00:00.000Z',
    };
    final older = {
      'id': 'pot_ord_old_s1',
      'sellerId': 's1',
      'orderId': 'ord_old',
      'salesGhs': 40,
      'netGhs': 37.6,
      'status': 'paid',
      'createdAt': '2026-10-01T11:00:00.000Z',
      'paidAt': '2026-10-01T12:00:00.000Z',
    };
    final merged = CloudStore.mergePayoutRows(
      local: [fresh, older],
      incoming: [older],
    );
    expect(
      merged.map((e) => e['id']),
      containsAll(['pot_ord_new_s1', 'pot_ord_old_s1']),
    );
    expect(
      merged.firstWhere((e) => e['id'] == 'pot_ord_new_s1')['status'],
      'pending',
    );
  });

  test('hydrate keeps paid over a stale pending cloud copy', () {
    const id = 'pot_ord_1_s1';
    final paid = {
      'id': id,
      'orderId': 'ord_1',
      'status': 'paid',
      'paidAt': '2026-10-07T12:00:00.000Z',
    };
    final pending = {'id': id, 'orderId': 'ord_1', 'status': 'pending'};
    expect(
      CloudStore.mergePayoutRows(
        local: [paid],
        incoming: [pending],
      ).single['status'],
      'paid',
    );
    expect(
      CloudStore.mergePayoutRows(
        local: [pending],
        incoming: [paid],
      ).single['status'],
      'paid',
    );
  });

  test('hydrate does not resurrect a cancelled payout from a stale pending copy',
      () {
    const id = 'pot_ord_1_s1';
    final cancelled = {'id': id, 'orderId': 'ord_1', 'status': 'cancelled'};
    final pending = {'id': id, 'orderId': 'ord_1', 'status': 'pending'};
    expect(
      CloudStore.mergePayoutRows(
        local: [cancelled],
        incoming: [pending],
      ).single['status'],
      'cancelled',
    );
    expect(
      CloudStore.mergePayoutRows(
        local: [pending],
        incoming: [cancelled],
      ).single['status'],
      'cancelled',
    );
  });

  test('hydrate keeps a reversed intake over a stale live copy', () {
    const id = 'tin_order_ord_1';
    final reversed = {
      'id': id,
      'source': 'order',
      'refId': 'ord_1',
      'amountGhs': 40,
      'reversed': true,
    };
    final live = {
      'id': id,
      'source': 'order',
      'refId': 'ord_1',
      'amountGhs': 40,
    };
    expect(
      CloudStore.mergeIntakeRows(
        local: [reversed],
        incoming: [live],
      ).single['reversed'],
      isTrue,
    );
    expect(
      CloudStore.mergeIntakeRows(
        local: [live],
        incoming: [reversed],
      ).single['reversed'],
      isTrue,
    );
  });

  test('hydrate keeps a local delivery a stale snapshot omitted', () {
    final fresh = {
      'id': 'del_new',
      'shipmentId': 'shp_new',
      'huberId': 'huber-1',
      'status': 'accepted',
    };
    final older = {
      'id': 'del_old',
      'shipmentId': 'shp_old',
      'huberId': 'huber-1',
      'status': 'delivered',
    };
    final merged = CloudStore.mergeDeliveryRows(
      local: [fresh, older],
      incoming: [older],
    );
    expect(
      merged.map((e) => e['id']),
      containsAll(['del_new', 'del_old']),
    );
    expect(
      merged.firstWhere((e) => e['id'] == 'del_new')['status'],
      'accepted',
    );
  });

  test('hydrate keeps delivered over a stale accepted cloud copy', () {
    const id = 'del_1';
    final delivered = {
      'id': id,
      'shipmentId': 'shp_1',
      'status': 'delivered',
    };
    final accepted = {
      'id': id,
      'shipmentId': 'shp_1',
      'status': 'accepted',
    };
    expect(
      CloudStore.mergeDeliveryRows(
        local: [delivered],
        incoming: [accepted],
      ).single['status'],
      'delivered',
    );
    expect(
      CloudStore.mergeDeliveryRows(
        local: [accepted],
        incoming: [delivered],
      ).single['status'],
      'delivered',
    );
  });

  test('hydrate does not resurrect a cancelled delivery from a stale accepted copy',
      () {
    const id = 'del_1';
    final cancelled = {
      'id': id,
      'shipmentId': 'shp_1',
      'status': 'cancelled',
    };
    final accepted = {
      'id': id,
      'shipmentId': 'shp_1',
      'status': 'accepted',
    };
    expect(
      CloudStore.mergeDeliveryRows(
        local: [cancelled],
        incoming: [accepted],
      ).single['status'],
      'cancelled',
    );
    expect(
      CloudStore.mergeDeliveryRows(
        local: [accepted],
        incoming: [cancelled],
      ).single['status'],
      'cancelled',
    );
  });

  test('hydrate keeps a local Huber profile a stale snapshot omitted', () {
    final fresh = {
      'id': 'huber-new',
      'walletBalanceGhs': 15,
      'completedCount': 1,
      'updatedAt': '2026-10-08T11:00:00.000Z',
    };
    final older = {
      'id': 'huber-old',
      'walletBalanceGhs': 0,
      'completedCount': 0,
      'updatedAt': '2026-10-01T11:00:00.000Z',
    };
    final merged = CloudStore.mergeHuberProfileRows(
      local: [fresh, older],
      incoming: [older],
    );
    expect(
      merged.map((e) => e['id']),
      containsAll(['huber-new', 'huber-old']),
    );
    expect(
      merged.firstWhere((e) => e['id'] == 'huber-new')['walletBalanceGhs'],
      15,
    );
  });

  test('hydrate keeps credited rider earnings over a stale empty wallet', () {
    const id = 'huber-1';
    final paid = {
      'id': id,
      'walletBalanceGhs': 25,
      'completedCount': 1,
      'updatedAt': '2026-10-08T12:00:00.000Z',
    };
    final stale = {
      'id': id,
      'walletBalanceGhs': 0,
      'completedCount': 0,
      'updatedAt': '2026-10-08T11:00:00.000Z',
    };
    expect(
      CloudStore.mergeHuberProfileRows(
        local: [paid],
        incoming: [stale],
      ).single['walletBalanceGhs'],
      25,
    );
    expect(
      CloudStore.mergeHuberProfileRows(
        local: [stale],
        incoming: [paid],
      ).single['walletBalanceGhs'],
      25,
    );
  });
}
