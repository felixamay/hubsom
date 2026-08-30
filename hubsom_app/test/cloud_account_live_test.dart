import 'package:flutter_test/flutter_test.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';

void main() {
  test('CloudStore writes and reads an account from Firestore', () async {
    CloudStore.useNetwork = true;
    const email = 'dart-live-verify@hubsom.test';
    await CloudStore.putAccount(email, {
      'name': 'Dart Live',
      'role': 'buyer',
      'salt': 'dart-salt',
      'hash': 'dart-hash',
      'userJson': {
        'id': 'dart-live-1',
        'email': email,
        'name': 'Dart Live',
        'role': 'buyer',
      },
    });
    final got = await CloudStore.getAccount(email);
    expect(got, isNotNull);
    expect(got!['email'], email);
    expect(got['hash'], 'dart-hash');
    expect(got['name'], 'Dart Live');
    final user = Map<String, dynamic>.from(got['userJson'] as Map);
    expect(user['id'], 'dart-live-1');
  });
}
