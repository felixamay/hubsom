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
}
