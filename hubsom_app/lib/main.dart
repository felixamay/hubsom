import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/auth/idle_session_guard.dart';
import 'core/config/app_config.dart';
import 'core/providers/core_providers.dart';
import 'core/services/firebase_bootstrap.dart';
import 'core/services/cloud_storage_status.dart';
import 'core/services/cloud_store.dart';
import 'core/services/local_blob_store.dart';
import 'core/services/local_commerce_store.dart';
import 'core/services/local_store.dart';
import 'core/services/product_demo_video_store.dart';
import 'core/services/storage_media.dart';
import 'core/services/user_address_store.dart';
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
  await LocalBlobStore.init();
  LocalStore.quotaMigrator = StorageMedia.migratePrefsBlobs;
  await ProductDemoVideoStore.init();
  await StorageMedia.migratePrefsBlobs();
  await LocalCommerceStore.migrateClearDemoOnce();
  await FirebaseBootstrap.init();
  // Learn whether this project has a Google Cloud Storage bucket before the
  // first video card renders, so posters and uploads pick the right path.
  // ignore: unawaited_futures
  CloudStorageStatus.ensureAvailable();
  // Catalog download must not hold the HTML "Loading…" splash. Home still
  // refreshes from the cloud after the first frame.
  // ignore: unawaited_futures
  CloudStore.hydrateLocalCache();
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationServiceProvider).init();
      // Silently refresh the user's GPS delivery address on every app open.
      // Only fires if location permission was already granted — no prompt shown.
      _refreshGpsAddress();
    });
  }

  /// If the user previously allowed location access, capture a fresh GPS fix
  /// and update their stored delivery address so riders always get the
  /// customer's real-time location, not a stale one.
  Future<void> _refreshGpsAddress() async {
    try {
      final locationService = ref.read(locationServiceProvider);
      final pin = await locationService.silentCurrent();
      if (pin == null) return;
      final user = ref.read(authStateProvider).valueOrNull;
      if (user == null) return;
      final next = await UserAddressStore.saveAllowedGps(
        user: user,
        pin: pin,
      );
      ref.read(authStateProvider.notifier).applyLocalUser(next);
    } catch (_) {
      // Best-effort: if anything fails, the saved address remains unchanged.
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Hubsom',
      debugShowCheckedModeBanner: false,
      theme: HubsomTheme.light(),
      routerConfig: router,
      builder: (context, child) {
        return IdleSessionGuard(child: child ?? const SizedBox.shrink());
      },
    );
  }
}
