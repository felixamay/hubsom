import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../config/firebase_options.dart';

/// Initializes Firebase for Hubsom Hosting / Firestore (`hubsom-web`).
class FirebaseBootstrap {
  FirebaseBootstrap._();

  static bool ready = false;

  static Future<void> init() async {
    if (!AppConfig.firebaseEnabled) return;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      }
      ready = true;
      if (kDebugMode) debugPrint('Firebase initialized');
    } catch (e) {
      ready = false;
      if (kDebugMode) debugPrint('Firebase init skipped: $e');
    }
  }
}
