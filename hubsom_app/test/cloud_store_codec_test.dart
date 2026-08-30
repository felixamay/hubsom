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
}
