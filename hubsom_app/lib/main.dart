import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/config/app_config.dart';
import 'core/providers/core_providers.dart';
import 'core/services/firebase_bootstrap.dart';
import 'core/services/cloud_store.dart';
import 'core/services/local_commerce_store.dart';
import 'core/services/local_store.dart';
import 'core/services/product_demo_video_store.dart';
import 'core/theme/hubsom_theme.dart';
import 'features/shell/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    usePathUrlStrategy();
  }
  AppConfig.load();
  await Hive.initFlutter();
  await LocalStore.init();
  await ProductDemoVideoStore.init();
  await LocalCommerceStore.migrateClearDemoOnce();
  await FirebaseBootstrap.init();
  await CloudStore.hydrateLocalCache();
  runApp(const ProviderScope(child: HubsomApp()));
}

class HubsomApp extends ConsumerStatefulWidget {
  const HubsomApp({super.key});

  @override
  ConsumerState<HubsomApp> createState() => _HubsomAppState();
}

class _HubsomAppState extends ConsumerState<HubsomApp> {
  @override
  void initState() {
    super.initState();
    // Warm notifications after first frame (mobile).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationServiceProvider).init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Hubsom',
      debugShowCheckedModeBanner: false,
      theme: HubsomTheme.light(),
      routerConfig: router,
    );
  }
}
