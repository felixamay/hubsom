import 'dart:async';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import 'cloud_storage_status.dart';
import 'firebase_bootstrap.dart';

/// Shop-video media on Google Cloud Storage (Firebase Storage).
///
/// Storage is the preferred home for clips: the browser streams them from the
/// CDN with range requests, so seeking works and Safari plays them. Firestore
/// chunks in [CloudVideoMedia] stay as the fallback for when Storage is not
/// enabled on the project.
class CloudMedia {
  CloudMedia._();

  /// Abort an upload that has not moved a single byte for this long. A hard
  /// overall deadline would kill slow-but-healthy uploads on a Ghana link.
  static const _stallTimeout = Duration(seconds: 60);

  static String videoPath(String videoId) => 'shopVideos/$videoId';
  static String thumbPath(String videoId) => 'shopVideos/${videoId}_thumb.jpg';
  static String liveCoverPath(String streamId) => 'liveCovers/$streamId.jpg';

  /// Cheap synchronous hint for widgets that cannot await a probe.
  static bool get storageKnownAvailable =>
      FirebaseBootstrap.ready && CloudStorageStatus.knownAvailable;

  static Future<bool> available() async {
    if (!FirebaseBootstrap.ready) return false;
    return CloudStorageStatus.ensureAvailable();
  }

  static FirebaseStorage get _storage {
    // A hand-made bucket needs the SDK pointed at it; the project default is
    // picked up automatically.
    final s = CloudStorageStatus.isCustomBucket
        ? FirebaseStorage.instanceFor(bucket: 'gs://${CloudStorageStatus.bucket}')
        : FirebaseStorage.instance;
    // Retries are per-operation; the stall watchdog owns the real deadline.
    s.setMaxUploadRetryTime(const Duration(seconds: 30));
    s.setMaxOperationRetryTime(const Duration(seconds: 20));
    return s;
  }

  /// Upload a clip and return its public https URL, or null when Storage is
  /// unavailable or the upload stalled.
  static Future<String?> uploadShopVideo({
    required String videoId,
    required Uint8List bytes,
    required String mimeType,
    void Function(double fraction)? onProgress,
  }) async {
    if (bytes.isEmpty || videoId.isEmpty) return null;
    if (!await available()) return null;
    try {
      final ref = _storage.ref().child(videoPath(videoId));
      final task = ref.putData(
        bytes,
        SettableMetadata(
          contentType: mimeType.isEmpty ? 'video/mp4' : mimeType,
          cacheControl: 'public,max-age=31536000,immutable',
        ),
      );
      final ok = await _awaitUpload(
        task,
        totalBytes: bytes.length,
        onProgress: onProgress,
      );
      if (!ok) return null;
      return await ref.getDownloadURL();
    } catch (e) {
      if (kDebugMode) debugPrint('CloudMedia.uploadShopVideo failed: $e');
      return null;
    }
  }

  /// JPEG still from a shop clip so Home / feed cards show a video frame.
  static Future<String?> uploadShopVideoThumb({
    required String videoId,
    required Uint8List bytes,
  }) async {
    if (bytes.isEmpty || videoId.isEmpty) return null;
    if (!await available()) return null;
    try {
      final ref = _storage.ref().child(thumbPath(videoId));
      await ref
          .putData(
            bytes,
            SettableMetadata(
              contentType: 'image/jpeg',
              cacheControl: 'public,max-age=31536000,immutable',
            ),
          )
          .timeout(const Duration(seconds: 45));
      return await ref.getDownloadURL();
    } catch (e) {
      if (kDebugMode) debugPrint('CloudMedia.uploadShopVideoThumb failed: $e');
      return null;
    }
  }

  /// Upload a live-stream cover thumbnail to Storage and return its download URL.
  static Future<String?> uploadLiveCover({
    required String streamId,
    required Uint8List bytes,
  }) async {
    if (bytes.isEmpty || streamId.isEmpty) return null;
    if (!await available()) return null;
    try {
      final ref = _storage.ref().child(liveCoverPath(streamId));
      await ref
          .putData(
            bytes,
            SettableMetadata(
              contentType: 'image/jpeg',
              cacheControl: 'public,max-age=86400',
            ),
          )
          .timeout(const Duration(seconds: 45));
      return await ref.getDownloadURL();
    } catch (e) {
      if (kDebugMode) debugPrint('CloudMedia.uploadLiveCover failed: $e');
      return null;
    }
  }

  static Future<String?> getShopVideoThumbUrl({required String videoId}) async {
    if (videoId.isEmpty) return null;
    if (!await available()) return null;
    try {
      final ref = _storage.ref().child(thumbPath(videoId));
      return await ref.getDownloadURL().timeout(const Duration(seconds: 15));
    } catch (e) {
      if (kDebugMode) debugPrint('CloudMedia.getShopVideoThumbUrl failed: $e');
      return null;
    }
  }

  /// Best-effort cleanup when a seller deletes their shop clip.
  static Future<void> deleteShopVideoAssets({required String videoId}) async {
    if (videoId.isEmpty) return;
    if (!await available()) return;
    for (final path in [videoPath(videoId), thumbPath(videoId)]) {
      try {
        await _storage
            .ref()
            .child(path)
            .delete()
            .timeout(const Duration(seconds: 20));
      } catch (e) {
        if (kDebugMode) {
          debugPrint('CloudMedia.deleteShopVideoAssets $path: $e');
        }
      }
    }
  }

  /// Await [task], reporting progress and cancelling if it stops moving.
  static Future<bool> _awaitUpload(
    UploadTask task, {
    required int totalBytes,
    void Function(double fraction)? onProgress,
  }) async {
    var transferred = 0;
    var lastMoved = DateTime.now();
    final done = Completer<bool>();

    final sub = task.snapshotEvents.listen(
      (snap) {
        if (snap.bytesTransferred <= transferred) return;
        transferred = snap.bytesTransferred;
        lastMoved = DateTime.now();
        if (totalBytes > 0) {
          onProgress?.call((transferred / totalBytes).clamp(0.0, 1.0));
        }
      },
      onError: (_) {},
      cancelOnError: false,
    );

    final watchdog = Timer.periodic(const Duration(seconds: 5), (_) {
      if (done.isCompleted) return;
      if (DateTime.now().difference(lastMoved) < _stallTimeout) return;
      done.complete(false);
    });

    unawaited(
      task.then(
        (_) {
          if (!done.isCompleted) done.complete(true);
        },
        onError: (Object e) {
          if (kDebugMode) debugPrint('CloudMedia upload error: $e');
          if (!done.isCompleted) done.complete(false);
        },
      ),
    );

    try {
      final ok = await done.future;
      if (!ok) {
        try {
          await task.cancel();
        } catch (_) {}
      }
      return ok;
    } finally {
      watchdog.cancel();
      await sub.cancel();
    }
  }
}
