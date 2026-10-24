import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase options for project `hubsom-web` (Hosting + Firestore accounts).
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return web;
      case TargetPlatform.iOS:
        return web;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDwSq6ho6TcTQdP7m9_sE3JWg3u3SLoC_M',
    appId: '1:604593114069:web:7e27472fbeb65857b6cb5c',
    messagingSenderId: '604593114069',
    projectId: 'hubsom-web',
    authDomain: 'hubsom-web.firebaseapp.com',
    storageBucket: 'hubsom-web.firebasestorage.app',
  );
}
