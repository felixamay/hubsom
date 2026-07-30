import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';

/// Initializes Firebase when enabled via `--dart-define=FIREBASE_ENABLED=true`.
/// Hubsom REST APIs remain the primary data source; Firebase Auth / Firestore /
/// Storage / Messaging are available for production without recreating collections.
class FirebaseBootstrap {
  FirebaseBootstrap._();

  static bool ready = false;

  static Future<void> init() async {
    if (!AppConfig.firebaseEnabled) return;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      ready = true;
      if (kDebugMode) debugPrint('Firebase initialized');
    } catch (e) {
      ready = false;
      if (kDebugMode) debugPrint('Firebase init skipped: $e');
    }
  }
}
