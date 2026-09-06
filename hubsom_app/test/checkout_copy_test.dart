import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/core/services/local_store.dart';
import 'package:hubsom_app/features/checkout/checkout_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _init() async {
  AppConfig.load();
  CloudStore.useNetwork = false;
  SharedPreferences.setMockInitialValues({});
  Hive.init(Directory.systemTemp.createTempSync('hubsom-checkout-copy').path);
  await LocalStore.init();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(_init);

  testWidgets('checkout does not tell the buyer who receives the payment',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: CheckoutPage()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Checkout'), findsOneWidget);
    expect(find.text('Payment'), findsOneWidget);
    expect(find.textContaining('Hubsom Admin'), findsNothing);
    expect(find.textContaining('admin account'), findsNothing);
    expect(find.textContaining('Paid to'), findsNothing);
    expect(find.textContaining('6%'), findsNothing);
    expect(find.textContaining('94%'), findsNothing);
    expect(find.textContaining('commission'), findsNothing);
  });
}
