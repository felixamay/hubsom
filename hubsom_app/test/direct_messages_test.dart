import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/repositories/message_repository.dart';
import 'package:hubsom_app/core/services/api_client.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/core/services/local_message_store.dart';
import 'package:hubsom_app/core/services/local_store.dart';
import 'package:hubsom_app/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    AppConfig.load();
    CloudStore.useNetwork = false;
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('hubsom-dms');
    Hive.init(dir.path);
    await LocalStore.init();
    await LocalStore.setSessionToken('sess');
    await LocalStore.setUserJson(
      jsonEncode({
        'id': 'u-buyer',
        'email': 'buyer@hubsom.test',
        'name': 'Buyer',
        'role': 'buyer',
      }),
    );
  });

  test('direct messages create inbox conversations and unread counts', () async {
    final seller = HubsomUser.fromJson({
      'id': 'u-seller',
      'email': 'seller@hubsom.test',
      'name': 'Seller Sam',
      'role': 'seller',
    });

    await LocalMessageStore.send(
      from: seller,
      toUserId: 'u-buyer',
      text: 'Thanks for your order!',
      toUserName: 'Buyer',
    );

    final repo = MessageRepository(ApiClient());
    final inbox = await repo.listConversations();
    expect(inbox, isNotEmpty);
    expect(inbox.first.userId, 'u-seller');
    expect(inbox.first.lastMessage, 'Thanks for your order!');
    expect(inbox.first.unreadCount, 1);
    expect(repo.unreadCount(), 1);

    await repo.markThreadRead('u-seller');
    expect(repo.unreadCount(), 0);

    await repo.send('u-seller', 'You are welcome');
    final thread = await repo.thread('u-seller');
    expect(thread.length, 2);
    expect(thread.last.text, 'You are welcome');
  });
}
