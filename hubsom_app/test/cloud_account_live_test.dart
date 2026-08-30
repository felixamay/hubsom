@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';

void main() {
  test('REST putAccount is visible to a later REST getAccount', () async {
    CloudStore.useNetwork = true;
    final email =
        'rest-verify-${DateTime.now().millisecondsSinceEpoch}@hubsom.test';
    await CloudStore.putAccount(email, {
      'name': 'REST Live',
      'role': 'buyer',
      'salt': 'rest-salt',
      'hash': 'rest-hash',
      'userJson': {
        'id': 'rest-live-1',
        'email': email,
        'name': 'REST Live',
        'role': 'buyer',
      },
    });
    final got = await CloudStore.getAccount(email);
    expect(got, isNotNull);
    expect(got!['email'], email);
    expect(got['hash'], 'rest-hash');
    expect(got['name'], 'REST Live');
    final user = Map<String, dynamic>.from(got['userJson'] as Map);
    expect(user['id'], 'rest-live-1');
  });
}
