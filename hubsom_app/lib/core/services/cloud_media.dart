import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import 'firebase_bootstrap.dart';

/// Uploads shop / demo video bytes to Firebase Storage for cross-device playback.
class CloudMedia {
  CloudMedia._();

  /// Flips false after the first failed Storage call this session. The
  /// project has no Storage bucket today, so every attempt would otherwise
  /// burn a slow link before the Firestore fallback gets a turn.
  static bool storageUsable = true;

  static bool get _canUseStorage =>
      storageUsable && FirebaseBootstrap.ready;

  static FirebaseStorage get _storage {
    final s = FirebaseStorage.instance;
    s.setMaxUploadRetryTime(const Duration(seconds: 20));
    s.setMaxOperationRetryTime(const Duration(seconds: 15));
    return s;
  }

  static Future<String?> uploadShopVideo({
    required String videoId,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (!_canUseStorage || bytes.isEmpty || videoId.isEmpty) {
      return null;
    }
    try {
      final ref = _storage.ref().child('shopVideos/$videoId');
      await ref.putData(
        bytes,
        SettableMetadata(
          contentType: mimeType.isEmpty ? 'video/mp4' : mimeType,
          cacheControl: 'public,max-age=31536000',
        ),
      );
      return await ref.getDownloadURL();
    } catch (e) {
      storageUsable = false;
      if (kDebugMode) debugPrint('CloudMedia.uploadShopVideo failed: $e');
      return null;
    }
  }

  /// JPEG still from a shop clip so Home / feed cards show a video frame.
  static Future<String?> uploadShopVideoThumb({
    required String videoId,
    required Uint8List bytes,
  }) async {
    if (!_canUseStorage || bytes.isEmpty || videoId.isEmpty) {
      return null;
    }
    try {
      // Lives under shopVideos/ so existing Storage rules allow the still.
      final ref = _storage.ref().child('shopVideos/${videoId}_thumb.jpg');
      await ref.putData(
        bytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'public,max-age=31536000',
        ),
      );
      return await ref.getDownloadURL();
    } catch (e) {
      storageUsable = false;
      if (kDebugMode) debugPrint('CloudMedia.uploadShopVideoThumb failed: $e');
      return null;
    }
  }

  static Future<String?> getShopVideoThumbUrl({required String videoId}) async {
    if (!_canUseStorage || videoId.isEmpty) return null;
    try {
      final ref = _storage.ref().child('shopVideos/${videoId}_thumb.jpg');
      return await ref.getDownloadURL();
    } catch (e) {
      if (kDebugMode) debugPrint('CloudMedia.getShopVideoThumbUrl failed: $e');
      return null;
    }
  }

  /// Best-effort cleanup when a seller deletes their shop clip.
  static Future<void> deleteShopVideoAssets({required String videoId}) async {
    if (!_canUseStorage || videoId.isEmpty) return;
    for (final path in [
      'shopVideos/$videoId',
      'shopVideos/${videoId}_thumb.jpg',
    ]) {
      try {
        await FirebaseStorage.instance.ref().child(path).delete();
      } catch (e) {
        if (kDebugMode) debugPrint('CloudMedia.deleteShopVideoAssets $path: $e');
      }
    }
  }
}
