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
}
