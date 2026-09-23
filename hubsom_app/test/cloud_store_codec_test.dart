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
}
