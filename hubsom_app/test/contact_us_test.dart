import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/core/services/local_message_store.dart';
import 'package:hubsom_app/core/services/local_store.dart';
import 'package:hubsom_app/core/support/support_chat.dart';
import 'package:hubsom_app/features/support/contact_us_page.dart';
import 'package:hubsom_app/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _buyer = HubsomUser(
  id: 'u-buyer',
  email: 'buyer@hubsom.test',
  name: 'Kojo Fan',
  role: 'buyer',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    AppConfig.load();
    CloudStore.useNetwork = false;
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('hubsom-contact');
    Hive.init(dir.path);
    await LocalStore.init();
  });

  test('contact chat goes to Hubsom Support and never names admin', () async {
    await LocalStore.setSessionToken('sess');
    await LocalStore.setUserJson(jsonEncode(_buyer.toJson()));

    final sent = await LocalMessageStore.send(
      from: _buyer,
      toUserId: SupportChat.peerId,
      text: 'I need help with my order',
    );
    expect(sent.toUserId, SupportChat.peerId);
    expect(sent.toUserName, SupportChat.displayName);
    expect(LocalMessageStore.resolvePeerName(SupportChat.peerId), 'Hubsom Support');

    final inbox = LocalMessageStore.conversationsFor(SupportChat.peerId);
    expect(inbox, hasLength(1));
    expect(inbox.first.userId, _buyer.id);
    expect(inbox.first.lastMessage, 'I need help with my order');

    await LocalMessageStore.send(
      from: SupportChat.asUser,
      toUserId: _buyer.id,
      text: 'We are on it',
    );
    final thread = LocalMessageStore.thread(_buyer.id, SupportChat.peerId);
    expect(thread.last.fromUserName, SupportChat.displayName);
    expect(thread.last.text, 'We are on it');

    final blob = jsonEncode([
      sent.toJson(),
      ...thread.map((m) => m.toJson()),
      SupportChat.pageTitle,
      SupportChat.intro,
      SupportChat.emptyPrompt,
      SupportChat.displayName,
    ]);
    expect(blob.toLowerCase().contains('admin'), isFalse);
  });

  testWidgets('Contact us page has no admin wording', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ContactUsPage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));

    expect(find.text('Contact us'), findsOneWidget);
    expect(find.text(SupportChat.intro), findsOneWidget);
    expect(find.text(SupportChat.emptyPrompt), findsOneWidget);
    expect(find.textContaining('admin'), findsNothing);
    expect(find.textContaining('Admin'), findsNothing);
    expect(find.textContaining('Afia'), findsNothing);
  });
}
