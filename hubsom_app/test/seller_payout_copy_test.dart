import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/core/services/local_store.dart';
import 'package:hubsom_app/features/seller/seller_hub_page.dart';
import 'package:hubsom_app/features/wallet/wallet_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _init() async {
  AppConfig.load();
  CloudStore.useNetwork = false;
  SharedPreferences.setMockInitialValues({});
  Hive.init(Directory.systemTemp.createTempSync('hubsom-seller-copy').path);
  await LocalStore.init();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(_init);

  testWidgets('seller hub does not show amounts waiting on admin', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SellerHubPage()),
    );
    await tester.pump();

    expect(find.text('Seller hub'), findsOneWidget);
    expect(find.textContaining('waiting on admin'), findsNothing);
    expect(find.textContaining('Hubsom Admin is holding'), findsNothing);
    expect(find.textContaining('Pending'), findsNothing);
    expect(find.textContaining('94%'), findsNothing);
    expect(find.textContaining('6%'), findsNothing);
  });

  testWidgets('wallet does not show amounts waiting on admin', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: WalletPage()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('waiting on admin'), findsNothing);
    expect(find.textContaining('Sales with admin'), findsNothing);
    expect(find.textContaining('Waiting on admin'), findsNothing);
    expect(find.textContaining('Paid by admin'), findsNothing);
    expect(find.textContaining('94%'), findsNothing);
  });
}
